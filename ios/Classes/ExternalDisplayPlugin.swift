import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    /// 外接畫面參數通道就緒後的回呼（主畫面等待用）
    public static var connectReturn: (() -> Void)?
    /// 主畫面外接螢幕狀態事件 sink（true = 已連接，false = 已拔除）
    public static var mainViewEvents: FlutterEventSink?
    /// 外接畫面接收參數的事件 sink
    public static var externalViewEvents: FlutterEventSink?

    /// 註冊外接 FlutterViewController 上的 GeneratedPlugin（由 AppDelegate 注入）
    public static var registerGeneratedPlugin: ((FlutterViewController) -> Void)?
    /// 外接引擎：主畫面 → 外接畫面的參數 EventChannel
    public static var receiveParameters: FlutterEventChannel?
    /// 外接引擎：外接畫面 → 主畫面的參數 MethodChannel
    public static var sendParameters: FlutterMethodChannel?
    /// 外接螢幕上的 UIWindow
    public static var externalWindow: UIWindow?
    /// 外接畫面專用的 FlutterEngine
    public static var externalEngine: FlutterEngine?

    /// Dart `connect` 尚未回傳時暫存的 FlutterResult（等待外接 UIScene 就緒）
    static var pendingConnectResult: FlutterResult?
    /// 待連接外接畫面的初始 route 名稱
    static var pendingRouteName: String = "externalView"
    /// connect 逾時工作項目（避免永久卡住）
    static var pendingConnectTimeout: DispatchWorkItem?

    /// iOS 27+ 的 scene accessory 註冊物件（系統據此呈現外接內容）
    static var sceneAccessoryRegistration: AnyObject?
    /// 目前註冊 scene accessory 的主畫面 ViewController
    static var accessoryHostViewController: UIViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // 監聽外接螢幕插拔狀態
        let onDisplayChange = FlutterEventChannel(
            name: "monitorStateListener",
            binaryMessenger: registrar.messenger()
        )
        onDisplayChange.setStreamHandler(MainViewHandler())

        // 控制連接／斷開／傳參等 method
        let connect = FlutterMethodChannel(
            name: "displayController",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getScreen":
            // 回傳目前可用螢幕資訊
            result(Self.screenInfos())

        case "connect":
            // 連接到外接螢幕並啟動外接 Flutter 內容
            Self.connect(call: call, result: result)

        case "disconnect":
            // 主動斷開外接畫面
            result(Self.disconnect())

        case "waitingTransferParametersReady":
            // 等待外接畫面參數通道就緒
            Self.waitingTransferParametersReady(result: result)

        case "sendParameters":
            // 主畫面 → 外接畫面傳參
            if Self.externalViewEvents != nil {
                Self.externalViewEvents?(call.arguments)
                result(true)
            } else {
                result(false)
            }

        default:
            result(false)
        }
    }

    // MARK: - Connect / Disconnect

    /// 連接外接螢幕：iOS 27+ 走 UISceneAccessory，舊版走 UIScreen
    static func connect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Mac 上的 iOS App 不支援外接顯示
        if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
            result(false)
            return
        }

        let args = call.arguments as? [String: Any]
        let routeName = (args?["routeName"] as? String) ?? "externalView"
        pendingRouteName = routeName

        if #available(iOS 27.0, *) {
            connectWithSceneAccessory(routeName: routeName, result: result)
        } else {
            connectWithLegacyScreen(routeName: routeName, result: result)
        }
    }

    /// 斷開外接畫面並清理資源
    static func disconnect() -> Bool {
        if #available(iOS 27.0, *) {
            // 停用 scene accessory，讓系統收回外接 scene
            if let registration = sceneAccessoryRegistration as? UISceneAccessoryRegistration {
                registration.isEnabled = false
            }
        }
        tearDownExternalSession(notifyUnplug: false)
        pendingConnectResult = nil
        return true
    }

    // MARK: - iOS 27+ UISceneAccessory

    /// iOS 27+：透過 UISceneAccessory 啟用外接非互動 scene
    @available(iOS 27.0, *)
    static func connectWithSceneAccessory(routeName: String, result: @escaping FlutterResult) {
        guard let host = findMainFlutterViewController() else {
            result(false)
            return
        }

        ensureSceneAccessoryRegistered(on: host)

        guard let registration = sceneAccessoryRegistration as? UISceneAccessoryRegistration else {
            result(false)
            return
        }
        // 優先用 registration.isAvailable；模擬器／過渡環境可退回 UIScreen 判斷
        guard registration.isAvailable || UIScreen.screens.count > 1 else {
            result(false)
            return
        }

        print("connectWithSceneAccessory")

        // 開始新連線前先清掉舊 session
        tearDownExternalSession(notifyUnplug: false)

        print("prepareExternalFlutterContent")

        pendingConnectResult = result
        prepareExternalFlutterContent(routeName: routeName)

        print("prepareExternalFlutterContent done")

        // 啟用 accessory 後，系統會非同步連上外接 scene
        registration.isEnabled = true

        print("registration.isEnabled = true")

        // 若 scene 已存在（例如已插著），直接掛載內容
        if let windowScene = findExternalWindowScene() {
            print("findExternalWindowScene found")
            attachExternalContent(to: windowScene)
            return
        }

        print("findExternalWindowScene done")

        // 啟用 accessory 後 scene 連線是非同步的，設定逾時避免永久等待
        pendingConnectTimeout?.cancel()
        let timeout = DispatchWorkItem {
            print("timeout")
            guard let pending = pendingConnectResult else { return }
            pendingConnectResult = nil
            tearDownExternalSession(notifyUnplug: false)
            registration.isEnabled = false
            pending(false)
        }
        pendingConnectTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeout)
    }

    /// 確保主畫面上已註冊 externalNonInteractive 的 scene accessory
    @available(iOS 27.0, *)
    static func ensureSceneAccessoryRegistered(on host: UIViewController) {
        // 同一個 host 已註冊過就不用重做
        if sceneAccessoryRegistration != nil, accessoryHostViewController === host {
            return
        }

        // host 換了就先從舊 host 解除註冊
        if let existing = sceneAccessoryRegistration as? UISceneAccessoryRegistration,
           let previousHost = accessoryHostViewController {
            previousHost.unregisterSceneAccessory(existing)
            sceneAccessoryRegistration = nil
            accessoryHostViewController = nil
        }

        // role 由 externalNonInteractive 決定，只需指定 scene delegate
        let configuration = UISceneConfiguration()
        configuration.delegateClass = ExternalDisplaySceneDelegate.self

        let accessory = UISceneAccessory.externalNonInteractive(sceneConfiguration: configuration)
        let registration = host.registerSceneAccessory(accessory)
        registration.isEnabled = false
        sceneAccessoryRegistration = registration
        accessoryHostViewController = host
    }

    /// 由 [ExternalDisplaySceneDelegate] 在外接 scene 即將連上時呼叫
    @available(iOS 27.0, *)
    static func handleExternalSceneWillConnect(_ scene: UIWindowScene) {
        attachExternalContent(to: scene)
        // 通知主畫面：外接螢幕已連上
        mainViewEvents?(true)
    }

    /// 外接 scene 斷開時清理，並停用 accessory
    @available(iOS 27.0, *)
    static func handleExternalSceneDidDisconnect() {
        tearDownExternalSession(notifyUnplug: true)
        if let registration = sceneAccessoryRegistration as? UISceneAccessoryRegistration {
            registration.isEnabled = false
        }
    }

    /// 將外接 Flutter 內容掛到指定的 UIWindowScene
    @available(iOS 27.0, *)
    static func attachExternalContent(to windowScene: UIWindowScene) {
        // 已有外接 window：只完成 pending connect（回傳尺寸）
        if externalWindow != nil {
            let size = windowScene.screen.bounds.size
            completePendingConnect(["height": size.height, "width": size.width])
            return
        }

        // 沒有進行中的 connect、也沒有既有引擎時不處理
        guard pendingConnectResult != nil || externalEngine != nil else {
            return
        }

        if externalEngine == nil {
            prepareExternalFlutterContent(routeName: pendingRouteName)
        }

        guard let engine = externalEngine else {
            completePendingConnect(false)
            return
        }

        let flutterViewController = FlutterViewController(
            engine: engine,
            nibName: nil,
            bundle: nil
        )
        registerGeneratedPlugin?(flutterViewController)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = flutterViewController
        window.makeKeyAndVisible()
        externalWindow = window

        // 讓 scene delegate 持有 window，避免被釋放
        if let sceneDelegate = windowScene.delegate as? ExternalDisplaySceneDelegate {
            sceneDelegate.window = window
        }

        let size = windowScene.screen.bounds.size
        completePendingConnect(["height": size.height, "width": size.width])
    }

    /// 在已連線 scenes 中尋找外接非互動 WindowScene
    @available(iOS 27.0, *)
    static func findExternalWindowScene() -> UIWindowScene? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if windowScene.session.role == .windowExternalDisplayNonInteractive {
                return windowScene
            }
        }
        return nil
    }

    // MARK: - Legacy UIScreen path (iOS < 27)

    /// iOS 27 以前：直接用 UIScreen.screens[1] 建立外接 UIWindow
    static func connectWithLegacyScreen(routeName: String, result: @escaping FlutterResult) {
        guard UIScreen.screens.count > 1 else {
            result(false)
            return
        }

        tearDownExternalSession(notifyUnplug: false)

        let externalScreen = UIScreen.screens[1]
        // 選最高解析度模式
        let mode = externalScreen.availableModes.last
        externalScreen.currentMode = mode
        guard let mode else {
            result(false)
            return
        }

        var frame = CGRect.zero
        frame.size = mode.size

        prepareExternalFlutterContent(routeName: routeName)
        guard let engine = externalEngine else {
            result(false)
            return
        }

        let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        registerGeneratedPlugin?(flutterViewController)
        flutterViewController.view.frame = frame

        let window = UIWindow(frame: frame)
        window.rootViewController = flutterViewController
        window.screen = externalScreen
        window.isHidden = false
        externalWindow = window

        result(["height": mode.size.height, "width": mode.size.width])
    }

    // MARK: - Shared helpers

    /// 建立外接 FlutterEngine，並設定雙向參數通道
    static func prepareExternalFlutterContent(routeName: String) {
        let flutterEngine = FlutterEngine(name: "external_display")
        // 使用獨立 entrypoint 啟動外接畫面
        flutterEngine.run(withEntrypoint: "externalDisplayMain", initialRoute: routeName)
        externalEngine = flutterEngine

        // 主畫面 → 外接畫面
        receiveParameters = FlutterEventChannel(
            name: "receiveParametersListener",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        receiveParameters?.setStreamHandler(ExternalViewHandler())

        // 外接畫面 → 主畫面
        sendParameters = FlutterMethodChannel(
            name: "sendParameters",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        flutterEngine.registrar(forPlugin: "ExternalDisplaySendParameters")?
            .addMethodCallDelegate(ExternalDisplaySendParameters(), channel: sendParameters!)
    }

    /// 拆除外接 session（window、通道、引擎）
    /// - Parameter notifyUnplug: 是否通知主畫面「已拔除」
    static func tearDownExternalSession(notifyUnplug: Bool) {
        externalWindow?.isHidden = true
        externalWindow?.rootViewController = nil
        externalWindow = nil

        receiveParameters?.setStreamHandler(nil)
        receiveParameters = nil
        sendParameters?.setMethodCallHandler(nil)
        sendParameters = nil
        externalViewEvents = nil

        if let engine = externalEngine {
            engine.destroyContext()
            externalEngine = nil
        }

        if notifyUnplug {
            mainViewEvents?(false)
        }
    }

    /// 完成（或取消逾時後）回傳 pending 的 connect result
    static func completePendingConnect(_ value: Any) {
        pendingConnectTimeout?.cancel()
        pendingConnectTimeout = nil
        guard let pending = pendingConnectResult else { return }
        pendingConnectResult = nil
        pending(value)
    }

    /// 取得目前螢幕／scene 尺寸與 role 字串列表（供除錯用）
    static func screenInfos() -> [String] {
        if #available(iOS 27.0, *) {
            var infos = [String]()
            var index = 0
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                let size = windowScene.screen.bounds.size
                let role = windowScene.session.role.rawValue
                infos.append(
                    "\(index). [\(Int(size.width))x\(Int(size.height))] (\(role))"
                )
                index += 1
            }
            if !infos.isEmpty {
                return infos
            }
        }

        return UIScreen.screens.enumerated().map { i, screen in
            "\(i). [\(Int(screen.nativeBounds.width))x\(Int(screen.nativeBounds.height))]"
        }
    }

    /// 尋找主畫面的 FlutterViewController（用來註冊 scene accessory）
    static func findMainFlutterViewController() -> FlutterViewController? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let flutter = window.rootViewController as? FlutterViewController {
                    return flutter
                }
                if let flutter = findFlutterViewController(in: window.rootViewController) {
                    return flutter
                }
            }
        }

        // 相容舊式 AppDelegate.window
        if let root = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
            return root
        }
        return findFlutterViewController(in: UIApplication.shared.delegate?.window??.rootViewController)
    }

    /// 遞迴在 child / presented VC 中尋找 FlutterViewController
    static func findFlutterViewController(in root: UIViewController?) -> FlutterViewController? {
        guard let root else { return nil }
        if let flutter = root as? FlutterViewController {
            return flutter
        }
        for child in root.children {
            if let flutter = findFlutterViewController(in: child) {
                return flutter
            }
        }
        return findFlutterViewController(in: root.presentedViewController)
    }

    /// 判斷目前是否有外接螢幕可用／已連線
    static func isExternalDisplayConnected() -> Bool {
        if #available(iOS 27.0, *) {
            if let registration = sceneAccessoryRegistration as? UISceneAccessoryRegistration,
               registration.isAvailable {
                return true
            }
            if findExternalWindowScene() != nil {
                return true
            }
        }
        return UIScreen.screens.count > 1
    }

    /// 等待外接畫面參數 EventChannel 就緒（最多約 10 秒）
    static func waitingTransferParametersReady(result: @escaping FlutterResult) {
        let sendFail = DispatchWorkItem {
            result(false)
            connectReturn = nil
        }

        func returnResolution() {
            sendFail.cancel()
            result(true)
            connectReturn = nil
        }
        connectReturn = returnResolution

        if externalViewEvents != nil {
            // 外接畫面已在聽，立刻回傳成功
            connectReturn?()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: sendFail)
        }
    }
}

// MARK: - External scene delegate (iOS 27+)

/// 供 [UISceneAccessory.externalNonInteractive] 使用的 Scene Delegate
@objc(ExternalDisplaySceneDelegate)
public class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard #available(iOS 27.0, *),
              let windowScene = scene as? UIWindowScene else {
            return
        }
        // 外接 scene 連上：掛載 Flutter 內容
        ExternalDisplayPlugin.handleExternalSceneWillConnect(windowScene)
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        if #available(iOS 27.0, *) {
            // 外接 scene 斷開：清理 session
            ExternalDisplayPlugin.handleExternalSceneDidDisconnect()
        }
        window = nil
    }
}

// MARK: - Parameter bridge

/// 外接畫面透過此 plugin 把參數送回主畫面
public class ExternalDisplaySendParameters: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        ExternalDisplayPlugin.mainViewEvents?(call.arguments)
        result(true)
    }
}

// MARK: - Main view stream

/// 主畫面監聽外接螢幕插拔狀態的 EventChannel handler
public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver: NSObjectProtocol?
    var didDisconnectObserver: NSObjectProtocol?

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events

        // Mac 上的 iOS App 不處理外接顯示
        if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
            return nil
        }

        // 提早註冊 scene accessory，讓 iOS 27+ 的 isAvailable 能反映插拔狀態
        if #available(iOS 27.0, *),
           let host = ExternalDisplayPlugin.findMainFlutterViewController() {
            ExternalDisplayPlugin.ensureSceneAccessoryRegistered(on: host)
        }

        // 若當下已連線，先推一次 true
        if ExternalDisplayPlugin.isExternalDisplayConnected() {
            events(true)
        }

        // 舊版 UIScreen 插拔通知（iOS 27 以前仍有效；之後 scene 路徑另有處理）
        didConnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { _ in
            events(true)
        }

        didDisconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { _ in
            ExternalDisplayPlugin.tearDownExternalSession(notifyUnplug: false)
            events(false)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let didConnectObserver {
            NotificationCenter.default.removeObserver(didConnectObserver)
        }
        if let didDisconnectObserver {
            NotificationCenter.default.removeObserver(didDisconnectObserver)
        }
        self.didConnectObserver = nil
        self.didDisconnectObserver = nil
        ExternalDisplayPlugin.mainViewEvents = nil
        return nil
    }
}

// MARK: - External view stream

/// 外接畫面接收參數的 EventChannel handler；開始 listen 時代表參數通道已就緒
public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        ExternalDisplayPlugin.externalViewEvents = events
        // 通知主畫面：傳參通道已可使用
        ExternalDisplayPlugin.connectReturn?()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
        ExternalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}

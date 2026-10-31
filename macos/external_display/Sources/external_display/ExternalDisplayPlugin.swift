import Cocoa
import FlutterMacOS

public class ExternalDisplayPlugin: NSObject, FlutterPlugin, NSWindowDelegate {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?
    
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    public static var externalWindow: NSWindow?
    public static var externalEngine: FlutterEngine?
    /// Observer that closes the external window when another app window closes.
    static var otherWindowCloseObserver: NSObjectProtocol?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 建立 Flutter EventChannel
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger)
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        // 建立 Flutter MethodChannel
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }

    /// Tear down external window, channels, and engine.
    /// - Parameters:
    ///   - notifyUnplug: Whether to notify the main view that the external display was removed.
    ///   - isClosing: Pass `true` when called from `windowWillClose` so we do not call `close()` again.
    public static func tearDownExternalSession(notifyUnplug: Bool, isClosing: Bool = false) {
        guard externalWindow != nil || externalEngine != nil else {
            return
        }

        if let observer = otherWindowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            otherWindowCloseObserver = nil
        }

        receiveParameters?.setStreamHandler(nil)
        receiveParameters = nil
        sendParameters?.setMethodCallHandler(nil)
        sendParameters = nil
        externalViewEvents = nil
        connectReturn = nil

        let window = externalWindow
        externalWindow = nil
        externalEngine = nil

        window?.delegate = nil
        window?.contentViewController = nil
        if !isClosing {
            window?.close()
        }

        if notifyUnplug {
            mainViewEvents?(false)
        }
    }

    // 接收主頁面的命令和參數
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "getScreen":
                let screens = NSScreen.screens
                var screenInfos = [String]()
                if #available(macOS 10.15, *) {
                    for i in 0..<screens.count {
                        let screen = screens[i]
                        screenInfos.append("\(i). \(screen.localizedName) [\(screen.frame.width)x\(screen.frame.height)]")
                    }
                } else {
                    for i in 0..<screens.count {
                        let screen = screens[i]
                        screenInfos.append("\(i). \(screen.frame.width)x\(screen.frame.height)")
                    }
                }
                result(screenInfos)
            
            // 連結外部顯示器
            case "createWindow":
                let args = call.arguments as? Dictionary<String, Any>
                let title = args?["title"] as? String ?? "External View"
                let fullscreen = args?["fullscreen"] as? Bool ?? false
                let windowWidth = args?["width"] as? Int ?? 1920
                let windowHeight = args?["height"] as? Int ?? 1080
                let screenIndex = args?["targetScreen"] as? Int ?? NSScreen.screens.count-1
 
                DispatchQueue.main.async {
                    var frame = NSScreen.screens[0].frame
                    let resolvedIndex: Int
                    if screenIndex >= 0 && screenIndex < NSScreen.screens.count {
                        resolvedIndex = screenIndex
                    } else {
                        resolvedIndex = NSScreen.screens.count - 1
                    }
                    frame = NSScreen.screens[resolvedIndex].frame
                    frame.origin.y = frame.maxY

                    if ExternalDisplayPlugin.externalWindow == nil {
                        ExternalDisplayPlugin.externalWindow = NSWindow(
                            contentRect: frame,
                            styleMask: [.titled, .closable, .miniaturizable, .resizable, .borderless],
                            backing: .buffered,
                            defer: true,
                            screen: NSScreen.screens[resolvedIndex]
                        )

                        let flutterEngine = FlutterEngine(name: "External Window", project: FlutterDartProject())
                        flutterEngine.run(withEntrypoint: "externalDisplayMain")
                        ExternalDisplayPlugin.externalEngine = flutterEngine
                        let externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                        ExternalDisplayPlugin.registerGeneratedPlugin?(externalViewController)

                        ExternalDisplayPlugin.receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: flutterEngine.binaryMessenger)
                        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(ExternalViewHandler())
                        ExternalDisplayPlugin.sendParameters = FlutterMethodChannel(name: "sendParameters", binaryMessenger: flutterEngine.binaryMessenger)
                        flutterEngine.registrar(forPlugin: "").addMethodCallDelegate(ExternalDisplaySendParameters(), channel: ExternalDisplayPlugin.sendParameters!)

                        ExternalDisplayPlugin.externalWindow?.title = title
                        ExternalDisplayPlugin.externalWindow?.contentViewController = externalViewController
                        ExternalDisplayPlugin.externalWindow?.isReleasedWhenClosed = false
                        ExternalDisplayPlugin.externalWindow?.setFrameAutosaveName("External Window")
                        ExternalDisplayPlugin.externalWindow?.delegate = self
                        
                        ExternalDisplayPlugin.otherWindowCloseObserver = NotificationCenter.default.addObserver(
                            forName: NSWindow.willCloseNotification,
                            object: nil,
                            queue: .main
                        ) { notification in
                            let window = notification.object as? NSWindow
                            if window != ExternalDisplayPlugin.externalWindow {
                                ExternalDisplayPlugin.tearDownExternalSession(notifyUnplug: true)
                            }
                        }
                    }
                    
                    if title != "External View" {
                        ExternalDisplayPlugin.externalWindow?.title = title
                    }
                        
                    ExternalDisplayPlugin.externalWindow?.orderFront(nil)
                    ExternalDisplayPlugin.externalWindow?.setFrameOrigin(frame.origin)
                    
                    if fullscreen {
                        ExternalDisplayPlugin.externalWindow?.toggleFullScreen(nil)
                    } else {
                        ExternalDisplayPlugin.externalWindow?.setContentSize(NSSize(width: windowWidth, height: windowHeight))
                    }

                    ExternalDisplayPlugin.mainViewEvents?(true)
                }

                result(true)
            
            case "destroyWindow":
                if ExternalDisplayPlugin.externalWindow != nil || ExternalDisplayPlugin.externalEngine != nil {
                    ExternalDisplayPlugin.tearDownExternalSession(notifyUnplug: true)
                    result(true)
                } else {
                    result(false)
                }
            
            case "connect":
                if ExternalDisplayPlugin.externalWindow != nil {
                    let size = ExternalDisplayPlugin.externalWindow?.contentView?.frame.size ?? NSSize(width: 1920, height: 1080)
                    result(["height":size.height, "width":size.width])
                } else {
                    result(false)
                }
            
            // 等候外部顯示器可以接收參數
            case "waitingTransferParametersReady":
                let sendFail = DispatchWorkItem(block: {
                    result(false)
                    ExternalDisplayPlugin.connectReturn = nil
                })
                
                func returnResolution() -> Void {
                    sendFail.cancel()
                    result(true)
                    ExternalDisplayPlugin.connectReturn = nil
                }
                ExternalDisplayPlugin.connectReturn = returnResolution

                
                if ExternalDisplayPlugin.externalViewEvents != nil {
                    ExternalDisplayPlugin.connectReturn?()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: sendFail)
                }
            
            // 發送參數到外部顯示頁面
            case "sendParameters":
                if ExternalDisplayPlugin.externalViewEvents != nil {
                    ExternalDisplayPlugin.externalViewEvents?(call.arguments)
                    result(true)
                } else {
                    result(false)
                }
            
            default:
                result(false)
        }
    }
    
    public func windowWillClose(_: Notification) {
        ExternalDisplayPlugin.tearDownExternalSession(notifyUnplug: true, isClosing: true)
    }
}

// 接收外部顯示頁面的命令和參數
public class ExternalDisplaySendParameters: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        ExternalDisplayPlugin.mainViewEvents?(call.arguments)
        result(true)
    }
}


// 主頁面 Flutter 開始和停止對 swift 傳送資料的監控
public class MainViewHandler: NSObject, FlutterStreamHandler {
    // 主頁面 Flutter 的開始監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events
        
        return nil
    }
    
    // 主頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = nil
        
        return nil
    }
}


// 外部顯示頁面 Flutter 開始和停止對 swift 傳送資料的監控
public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.externalViewEvents = events
        ExternalDisplayPlugin.connectReturn?()
        return nil
    }

    // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
        ExternalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}

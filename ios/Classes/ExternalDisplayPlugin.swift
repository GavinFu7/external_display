import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?
    
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    var externalWindow:UIWindow?
    var router:String = ""
    var externalViewController:FlutterViewController!

    // 初始化
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 建立 Flutter EventChannel
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger())
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        // 建立 Flutter MethodChannel
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }
    
    // 接收主頁面的命令和參數
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            // 連結外部顯示器
            case "connect":
                if (UIScreen.screens.count > 1) {
                    let args = call.arguments as? Dictionary<String, String>
                    let routeName = args?["routeName"] ?? "externalView"
                    let externalScreen = UIScreen.screens[1]
                    let mode = externalScreen.availableModes.last
                    externalScreen.currentMode = mode;
                    var frame = CGRect.zero
                    frame.size = mode!.size

                    if (externalWindow == nil || routeName != router) {
                        let flutterEngine = FlutterEngine()
                        flutterEngine.run(withEntrypoint: "externalDisplayMain", initialRoute: routeName)
                        externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                        ExternalDisplayPlugin.registerGeneratedPlugin?(externalViewController)
                        
                        ExternalDisplayPlugin.receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: externalViewController.binaryMessenger)
                        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(ExternalViewHandler())
                        ExternalDisplayPlugin.sendParameters = FlutterMethodChannel(name: "sendParameters", binaryMessenger: externalViewController.binaryMessenger)
                        flutterEngine.registrar(forPlugin: "")?.addMethodCallDelegate(ExternalDisplaySendParameters(), channel: ExternalDisplayPlugin.sendParameters!)
                        
                        externalViewController.view.frame = frame
                        externalWindow = UIWindow(frame: frame)
                    } else {
                        externalViewController.view.frame = frame
                        externalWindow?.frame = frame
                        externalViewController.view.setNeedsLayout()
                    }
                    externalWindow?.rootViewController = externalViewController
                    externalWindow?.screen = externalScreen
                    externalWindow?.isHidden = false

                    result(["height":mode!.size.height, "width":mode!.size.width])
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

                
                if (ExternalDisplayPlugin.externalViewEvents != nil) {
                    ExternalDisplayPlugin.connectReturn?()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: sendFail)
                }
            
            // 發送參數到外部顯示頁面
            case "sendParameters":
                if (ExternalDisplayPlugin.externalViewEvents != nil) {
                    ExternalDisplayPlugin.externalViewEvents?(call.arguments)
                    result(true)
                } else {
                    result(false)
                }

            default:
                result(FlutterMethodNotImplemented)
        }
    }
}

// 接收外部顯示頁面的命令和參數
public class ExternalDisplaySendParameters: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        ExternalDisplayPlugin.mainViewEvents?(call.arguments)
    }
}

// 主頁面 Flutter 開始和停止對 swift 傳送資料的監控
public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver:NSObjectProtocol?
    var didDisconnectObserver:NSObjectProtocol?
    
    // 主頁面 Flutter 的開始監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events
        if #available(iOS 14.0, *) {
            // 檢查是否Mac機
            if (ProcessInfo.processInfo.isiOSAppOnMac) {
                return nil
            }
        }

        // 檢查是否已連接外部顯示器
        if (UIScreen.screens.count > 1) {
            events(true)
        }
        
        // 開始監控插入外部顯示器
        didConnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didConnectNotification, object:nil, queue:nil) {_ in
            events(true)
        }
        
        // 開始監控拔出外部顯示器
        didDisconnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didDisconnectNotification, object:nil, queue: nil) {_ in
            ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
            ExternalDisplayPlugin.receiveParameters = nil
            ExternalDisplayPlugin.externalViewEvents = nil
            events(false)
        }
        return nil
    }
    
    // 主頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // 停止監控插入和拔出外部顯示器
        NotificationCenter.default.removeObserver(didConnectObserver)
        NotificationCenter.default.removeObserver(didDisconnectObserver)
        // 取消 swift 傳回的資料功能
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
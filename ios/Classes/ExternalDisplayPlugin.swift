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

    public static func register(with registrar: FlutterPluginRegistrar) {
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger())
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
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
                    externalWindow?.makeKeyAndVisible()

                    result(["height":mode!.size.height, "width":mode!.size.width])
                } else {
                    result(false)
                }
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
            case "transferParameters":
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

public class ExternalDisplaySendParameters: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        ExternalDisplayPlugin.mainViewEvents?(call.arguments)
    }
}

public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver:NSObjectProtocol?
    var didDisconnectObserver:NSObjectProtocol?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events
        if #available(iOS 14.0, *) {
            if (ProcessInfo.processInfo.isiOSAppOnMac) {
                return nil
            }
        }

        if (UIScreen.screens.count > 1) {
            events(true)
        }
        
        didConnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didConnectNotification, object:nil, queue:nil) {_ in
            events(true)
        }
        
        didDisconnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didDisconnectNotification, object:nil, queue: nil) {_ in
            ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
            ExternalDisplayPlugin.receiveParameters = nil
            ExternalDisplayPlugin.externalViewEvents = nil
            events(false)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(didConnectObserver)
        NotificationCenter.default.removeObserver(didDisconnectObserver)
        ExternalDisplayPlugin.mainViewEvents = nil
        
        return nil
    }
}

public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.externalViewEvents = events
        ExternalDisplayPlugin.connectReturn?()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
        ExternalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}

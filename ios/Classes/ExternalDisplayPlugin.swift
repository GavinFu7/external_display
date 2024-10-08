import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    var externalWindow:UIWindow?
    var router:String = ""
    var connectReturn:(() -> Void)?
    var externalViewController:FlutterViewController!
    public var externalViewEvents:FlutterEventSink?
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    

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
                    
                    let receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: externalViewController.binaryMessenger)
                    receiveParameters.setStreamHandler(ExternalViewHandler(plugin: self))
                    
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
            func returnResolution() -> Void {
                result(true)
                connectReturn = nil
            }
            connectReturn = returnResolution

            if (externalViewEvents != nil) {
                connectReturn?()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    if (self.connectReturn != nil) {
                        result(false)
                        self.connectReturn = nil
                    }
                }
            }
        case "transferParameters":
            if (externalViewEvents != nil) {
                externalViewEvents?(call.arguments)
                result(true)
            } else {
                result(false)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver:NSObjectProtocol?
    var didDisconnectObserver:NSObjectProtocol?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
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
            events(false)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(didConnectObserver)
        NotificationCenter.default.removeObserver(didDisconnectObserver)
        
        return nil
    }
}

public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    var externalDisplayPlugin : ExternalDisplayPlugin
    
    init(plugin : ExternalDisplayPlugin) {
        externalDisplayPlugin = plugin
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        externalDisplayPlugin.externalViewEvents = events
        externalDisplayPlugin.connectReturn?()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        externalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}

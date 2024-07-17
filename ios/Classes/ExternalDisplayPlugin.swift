import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    var externalWindow:UIWindow?
    var externalViewController:UIViewController?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger())
        onDisplayChange.setStreamHandler(ExternalDisplayPlugin())
        
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
                if (externalWindow == nil) {
                    externalViewController = FlutterViewController(project: nil, initialRoute: routeName, nibName: nil, bundle: nil)
                    externalWindow = UIWindow(frame: frame)
                } else {
                    externalViewController?.view.setNeedsLayout()
                    externalWindow?.frame = frame
                }
                externalWindow?.rootViewController = externalViewController
                externalWindow?.screen = externalScreen
                externalWindow?.makeKeyAndVisible()
                
                result(["height":frame.size.height, "width":frame.size.width])
            } else {
                result(false)
            }
        case "getCurrentSize":
            if (UIScreen.screens.count > 1) {
                let size = UIScreen.screens[1].currentMode?.size
                result(["height":size?.height, "width":size?.width])
            } else {
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        debugPrint(UIScreen.screens)
        if (UIScreen.screens.count > 1) {
            events(true)
        }
        
        NotificationCenter.default.addObserver(forName:UIScreen.didConnectNotification, object:nil, queue:nil) {_ in
            events(true)
        }
        
        NotificationCenter.default.addObserver(forName:UIScreen.didDisconnectNotification, object:nil, queue: nil) {_ in
            events(false)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}


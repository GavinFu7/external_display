import Cocoa
import FlutterMacOS

public class ExternalDisplayPlugin: NSObject, FlutterPlugin, NSWindowDelegate {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?
    
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    var router:String = ""
    var externalViewController:FlutterViewController!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
    
        // 建立 Flutter EventChannel
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger)
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        // 建立 Flutter MethodChannel
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }

    // 接收主頁面的命令和參數
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            // 連結外部顯示器
            case "createWindow":
                if NSApp.windows.contains(where: { $0.frameAutosaveName == "External Window" }) {
                    return result(false)
                }
            
                let args = call.arguments as? Dictionary<String, String>
                let title = args?["title"] ?? "External View"
                
                DispatchQueue.main.async {
                    let externalWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                        styleMask: [.titled, .closable, .miniaturizable],
                        backing: .buffered,
                        defer: false
                    )
                    
                    externalWindow.title = title
                    externalWindow.isReleasedWhenClosed = false
                    externalWindow.setFrameAutosaveName("External Window")
                    externalWindow.orderFront(nil)
                    
                    externalWindow.delegate = self;

                    ExternalDisplayPlugin.mainViewEvents?(true)
                }

                result(true)
            
            case "destroyWindow":
                NSApp.windows.forEach { (win) in
                    if win.frameAutosaveName=="External Window" {
                        win.close()
                        return result(true)
                    }
                }
                result(false)
            
            case "connect":
                guard let externalWindow = NSApp.windows.first(where: {
                    $0.frameAutosaveName == "External Window"
                }) else {
                    return result(false)
                }
            
                let args = call.arguments as? Dictionary<String, String>
                let routeName = args?["routeName"] ?? "externalView"
                
                if (externalViewController == nil) {
                    let flutterEngine = FlutterEngine(name: routeName, project: FlutterDartProject())
                    flutterEngine.run(withEntrypoint: "externalDisplayMain")
                    externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                    ExternalDisplayPlugin.registerGeneratedPlugin?(externalViewController)

                    ExternalDisplayPlugin.receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: flutterEngine.binaryMessenger)
                    ExternalDisplayPlugin.receiveParameters?.setStreamHandler(ExternalViewHandler())
                    ExternalDisplayPlugin.sendParameters = FlutterMethodChannel(name: "sendParameters", binaryMessenger: flutterEngine.binaryMessenger)
                    flutterEngine.registrar(forPlugin: "").addMethodCallDelegate(ExternalDisplaySendParameters(), channel: ExternalDisplayPlugin.sendParameters!)
                }
            
                let size = externalWindow.contentView?.frame.size ?? NSSize(width: 1920, height: 1080)
            
                externalWindow.contentViewController = externalViewController
                externalWindow.setContentSize(size)
            
                result(["height":size.height, "width":size.width])
            
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
        return nil
    }

    // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

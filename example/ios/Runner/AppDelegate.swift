import UIKit
import Flutter
import external_display

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
  func registerGeneratedPlugin(controller:FlutterViewController) {
    GeneratedPluginRegistrant.register(with: controller)
  }
}

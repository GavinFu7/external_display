import Cocoa
import FlutterMacOS
import external_display

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func registerGeneratedPlugin(controller:FlutterViewController) {
      RegisterGeneratedPlugins(registry: controller)
  }
}

# External Display

The Flutter plugin supports connecting to an external display via wired or wireless connections. The main view and the external display view can exchange data with each other.

## Getting Started

### macOS

If you need to use other Flutter plugins (e.g., `path_provider`, `shared_preferences`, etc.) in window created by the `external_display` plugin, you must add the following code to your `AppDelegate.swift`:

```swift
import external_display
.
.
override func applicationDidFinishLaunching(_ aNotification: Notification) {
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
    .
    .
}

func registerGeneratedPlugin(controller: FlutterViewController) {
    RegisterGeneratedPlugins(registry: controller)
}
```

Example: <https://github.com/GavinFu7/external_display/blob/main/example/macos/Runner/AppDelegate.swift>

#### Create Window (macOS-only)

```dart
final created = await externalDisplay.createWindow({
  String? title,
  bool? fullscreen,
  int? width,
  int? height,
  int? targetScreen,
}); // Future<bool>
```

**Parameters:**

* `title`: Window title (displayed in the title bar)

* `fullscreen`: Whether to display in fullscreen mode

* `width`: Window width (in pixels)

* `height`: Window height (in pixels)

* `targetScreen`: Display screen index (which screen to show the window on)

#### Destroy Window (macOS-only)

```dart
final destroyed = await externalDisplay.destroyWindow(); // Future<bool>
```

---

### iOS

#### 1. Adopt the UIScene lifecycle (required for iOS 27)

iOS 27 / Xcode 27 requires the `UIScene` lifecycle. Add an Application Scene Manifest to your `Info.plist` (see the [Flutter UIScene migration guide](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)):

```xml
<key>UIApplicationSceneManifest</key>
<dict>
  <key>UIApplicationSupportsMultipleScenes</key>
  <false/>
  <key>UISceneConfigurations</key>
  <dict>
    <key>UIWindowSceneSessionRoleApplication</key>
    <array>
      <dict>
        <key>UISceneClassName</key>
        <string>UIWindowScene</string>
        <key>UISceneDelegateClassName</key>
        <string>FlutterSceneDelegate</string>
        <key>UISceneConfigurationName</key>
        <string>flutter</string>
        <key>UISceneStoryboardFile</key>
        <string>Main</string>
      </dict>
    </array>
  </dict>
</dict>
```

#### 2. Register plugins for UIScene (required)

With UIScene, register plugins via `FlutterPluginRegistrant` / `pluginRegistrant`. If you need other Flutter plugins (e.g. `path_provider`) on the external display, also set `ExternalDisplayPlugin.registerGeneratedPlugin`:

```swift
import UIKit
import Flutter
import external_display

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }

  func registerGeneratedPlugin(controller: FlutterViewController) {
    GeneratedPluginRegistrant.register(with: controller)
  }
}
```

Example: <https://github.com/GavinFu7/external_display/blob/main/example/ios/Runner/AppDelegate.swift>

#### 3. UISceneAccessory for external displays (iOS 27+)

Starting with **iOS 27**, custom content on a non-interactive external display is only delivered after the app registers a [`UISceneAccessory`](https://developer.apple.com/documentation/uikit/uisceneaccessory).

This plugin handles that for you:

* On iOS 27+, `connect()` registers `UISceneAccessory.externalNonInteractive` on the main `FlutterViewController`, enables it, and attaches a `UIWindow` in `ExternalDisplaySceneDelegate` when the system connects the external scene.
* On iOS 15–26, the plugin keeps the legacy `UIScreen` + `UIWindow.screen` path.
* Host apps do **not** need to register `UISceneAccessory` manually.

Dart usage is unchanged:

```dart
await externalDisplay.connect();
```

### External Display Entry Point `externalDisplayMain`

```dart
@pragma('vm:entry-point')
void externalDisplayMain() {}
```

### Monitor External Display Plugging and Unplugging

```dart
void onDisplayChange(bool connecting) { /* ... */ }

externalDisplay.addStatusListener(onDisplayChange);
```

### Cancel External Display Monitoring

```dart
externalDisplay.removeStatusListener(onDisplayChange);
```

### Get the Connection Status

```dart
externalDisplay.isPlugging
```

### Get the External Display Resolution

```dart
externalDisplay.resolution
```

### Connecting to the External Display

```dart
final connected = await externalDisplay.connect({
  String? routeName,
  int? targetScreen,
}); // Future<bool>
```

Returns `true` when connected and `resolution` is updated; otherwise `false`.

**Parameters:**

* `routeName`: Works with Flutter's MaterialApp `routes` property to define which route should launch the application.
> ⚠️ Not recommended for use (this parameter has no effect on macOS).

* `targetScreen`: Specifies which display screen to use (defaults to the last connected screen).
> ⚠️ Android-only parameter (has no effect on other platforms).

### Disconnecting from the External Display

```dart
final disconnected = await externalDisplay.disconnect({String? routeName}); // Future<bool>
```


---

## Main View: Transferring Parameters

### Add a Listener to Receive Parameters from the External View

```dart
transferParameters.addListener(({required action, value}) {
  print(action);
  print(value);
});
```

### Remove the Listener

```dart
transferParameters.removeListener(receive);
```

### Transfer Parameters to the External View

```dart
await externalDisplay.sendParameters(action: actionName, value: parameters);
```

### Wait for External Monitor to Be Ready to Receive Parameters

If you need to transfer parameters immediately after connecting to the external monitor, use `waitingTransferParametersReady` to ensure the external monitor is ready to receive data.

```dart
final connected = await externalDisplay.connect();
if (!connected) {
  return;
}

// Returns Future<bool>; onReady / onError are optional helpers.
final ready = await externalDisplay.waitingTransferParametersReady(
  onReady: () {
    print("Ready to transfer parameters, sending data!");
    externalDisplay.sendParameters(action: "action", value: "data");
  },
  onError: () { // Waiting timeout
    print("Failed to transfer parameters!");
  },
);
```

---

## External View: Transferring Parameters

### Import `transfer_parameters.dart`

```dart
import 'package:external_display/transfer_parameters.dart';
```

### Add a Listener to Receive Parameters from the Main View

```dart
transferParameters.addListener(({required action, value}) {
  print(action);
  print(value);
});
```

### Remove the Listener

```dart
transferParameters.removeListener(receive);
```

### Transfer Parameters to the Main View

```dart
await transferParameters.sendParameters(action: actionName, value: parameters);
```

---

## Example

```dart
import 'package:flutter/material.dart';
// Import external display package
import 'package:external_display/external_display.dart';

void main() {
  // Launch the main application
  runApp(const MyApp());
}

// This annotation tells Flutter that this is the entry point for external display
@pragma('vm:entry-point')
void externalDisplayMain() {
  // Create a separate MaterialApp for external display
  runApp(const MaterialApp(
    // Set the home page for external display
    home: ExternalView(),
  ));
}

// Main application component
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // Set the home page of the application
      home: Home(),
    );
  }
}

// External display view component
class ExternalView extends StatelessWidget {
  const ExternalView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        // Text displayed on external display
        child: Text('This is the external view.'),
      ),
    );
  }
}

// Home page component
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

// Home page state class
class _HomeState extends State<Home> {
  // Create external display instance
  ExternalDisplay externalDisplay = ExternalDisplay();
  // External display connection status
  String state = "Unplugged";
  // External display resolution information
  String resolution = "";

  // Callback function when external display connection status changes
  void onDisplayChange(bool connecting) {
    setState(() {
      if (connecting) {
        // Update to connected status
        state = "Plugged";
      } else {
        // Update to disconnected status
        state = "Unplugged";
        // Clear resolution information
        resolution = "";
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Add display status change listener
    externalDisplay.addStatusListener(onDisplayChange);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // App bar title
        title: const Text('External Display Example'),
      ),
      body: Container(
        // Set background color to white
        color: Colors.white,
        child: Column(
          children: [
            // Container for displaying external display status
            Container(
              height: 100,
              alignment: Alignment.center,
              // Display current connection stat
              child: Text("External Monitor is $state"),
            ),
            // Connect button container
            Container(
              height: 100,
              alignment: Alignment.center,
              child: TextButton(
                style: ButtonStyle(
                   // Button text color
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: () async {
                  // Connect to external display
                  final connected = await externalDisplay.connect();
                  setState(() {
                    // Update resolution information
                    resolution = connected
                        ? "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px"
                        : "";
                  });
                },
                child: const Text("Connect"), // Button text
              ),
            ),
            // Container for displaying resolution information
            Container(
              height: 100,
              alignment: Alignment.center,
              // Display external display resolution
              child: Text(resolution),
            ),
          ],
        ),
      ),
    );
  }
}
```
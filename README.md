# External Display

The Flutter plugin supports connecting to an external display via wired or wireless connections. The main view and the external display view can exchange data with each other.

## Platform support

| Platform | Supported |
| --- | --- |
| iOS / Android / macOS | ✅ |
| Windows / Linux / Web | ❌ |

## Getting Started

Import the package and use the shared `externalDisplay` instance:

```dart
import 'package:external_display/external_display.dart';
```

### macOS

If you need to use other Flutter plugins (e.g., `path_provider`, `shared_preferences`, etc.) in a window created by the `external_display` plugin, you must add the following code to your `AppDelegate.swift`:

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
final created = await externalDisplay.createWindow(
  title: 'External View',
  fullscreen: false,
  width: 1920,
  height: 1080,
  targetScreen: null, // defaults to the last screen
); // Future<bool>
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

Define a separate Dart entrypoint for the external display engine. Annotate it with `@pragma('vm:entry-point')` so it is not tree-shaken:

```dart
@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(home: ExternalView()));
}
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

### Get Available Screens

```dart
final screens = await externalDisplay.getScreen(); // Future<List<String>>
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
final connected = await externalDisplay.connect(
  routeName: 'externalView',
  targetScreen: null,
); // Future<bool>
```

Returns `true` when connected and `resolution` is updated; otherwise `false`.

**Parameters:**

* `routeName`: Works with Flutter's MaterialApp `routes` / `onGenerateRoute` to choose which route to show on the external display.
> ⚠️ Not recommended for use (this parameter has no effect on macOS).

* `targetScreen`: Specifies which display screen to use (defaults to the last connected screen).
> ⚠️ Android-only parameter (has no effect on other platforms).

### Disconnecting from the External Display

```dart
final disconnected = await externalDisplay.disconnect(
  routeName: 'externalView',
); // Future<bool>
```

### Dispose

The package exposes a process-wide `externalDisplay` instance. If you no longer need plug/unplug or parameter listeners, call:

```dart
externalDisplay.dispose();
```

To remove only one listener, prefer `removeStatusListener` / `removeReceiveParameterListener` instead.

---

## Main View: Transferring Parameters

Use `externalDisplay` on the main view. Do **not** use `transferParameters` here.

### Add a Listener to Receive Parameters from the External View

```dart
void onReceiveParameters({required String action, dynamic value}) {
  print(action);
  print(value);
}

externalDisplay.addReceiveParameterListener(onReceiveParameters);
```

### Remove the Listener

```dart
externalDisplay.removeReceiveParameterListener(onReceiveParameters);
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

On the external display entrypoint, use `TransferParameters` (or the shared `transferParameters` instance). Prefer creating a dedicated instance per external page and disposing it with the page lifecycle.

### Import `transfer_parameters.dart`

```dart
import 'package:external_display/transfer_parameters.dart';
```

### Add a Listener to Receive Parameters from the Main View

```dart
void onReceiveParameters({required String action, dynamic value}) {
  print(action);
  print(value);
}

transferParameters.addListener(onReceiveParameters);
```

### Remove the Listener

```dart
transferParameters.removeListener(onReceiveParameters);
```

### Transfer Parameters to the Main View

```dart
await transferParameters.sendParameters(action: actionName, value: parameters);
```

### Dispose

```dart
transferParameters.dispose();
```

---

## Example

Minimal example. For the full sample app, see [`example/`](example/).

```dart
import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(home: ExternalView()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class ExternalView extends StatelessWidget {
  const ExternalView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This is the external view.')),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String state = 'Unplugged';
  String resolution = '';

  void onDisplayChange(bool connecting) {
    setState(() {
      if (connecting) {
        state = 'Plugged';
      } else {
        state = 'Unplugged';
        resolution = '';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    externalDisplay.addStatusListener(onDisplayChange);
  }

  @override
  void dispose() {
    externalDisplay.removeStatusListener(onDisplayChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('External Display Example')),
      body: Column(
        children: [
          SizedBox(
            height: 100,
            child: Center(child: Text('External Monitor is $state')),
          ),
          SizedBox(
            height: 100,
            child: Center(
              child: TextButton(
                onPressed: () async {
                  final connected = await externalDisplay.connect();
                  setState(() {
                    resolution = connected
                        ? 'width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px'
                        : '';
                  });
                },
                child: const Text('Connect'),
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: Center(child: Text(resolution)),
          ),
        ],
      ),
    );
  }
}
```

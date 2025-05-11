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
await externalDisplay.createWindow({String? title, bool? fullscreen, int? width, int? height, int? targetScreen})
```

**Parameters:**

* `title`: Window title (displayed in the title bar)

* `fullscreen`: Whether to display in fullscreen mode

* `width`: Window width (in pixels)

* `height`: Window height (in pixels)

* `targetScreen`: Display screen index (which screen to show the window on)

#### Destroy Window (macOS-only)

```dart
await externalDisplay.destroyWindow()
```

---

### iOS

If you need to use other Flutter plugins (e.g., `path_provider`, `shared_preferences`, etc.) in view created by the `external_display` plugin, you must add the following code to your `AppDelegate.swift`:

```swift
import external_display
.
.
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
    .
    .
}

func registerGeneratedPlugin(controller: FlutterViewController) {
    GeneratedPluginRegistrant.register(with: controller)
}
```

Example: <https://github.com/GavinFu7/external_display/blob/main/example/ios/Runner/AppDelegate.swift>

### External Display Entry Point `externalDisplayMain`

```dart
@pragma('vm:entry-point')
void externalDisplayMain() {}
```

### Monitor External Display Plugging and Unplugging

```dart
externalDisplay.addListener(onDisplayChange);
```

### Cancel External Display Monitoring

```dart
externalDisplay.removeListener(onDisplayChange);
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
await externalDisplay.connect({String? routeName, int? targetScreen});
```

**Parameters:**

* `routeName`: Works with Flutter's MaterialApp `routes` property to define which route should launch the application.
> ⚠️ Not recommended for use (this parameter has no effect on macOS).

* `targetScreen`: Specifies which display screen to use (defaults to the last connected screen).
> ⚠️ Android-only parameter (has no effect on other platforms).


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
externalDisplay.connect();
externalDisplay.waitingTransferParametersReady(
  onReady: () {
    print("Ready to transfer parameters, sending data!");
    externalDisplay.transferParameters(action: "action", value: "data");
  },
  onError: () { // Waiting timeout
    print("Failed to transfer parameters!");
  }
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
import 'package:external_display/external_display.dart';

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(
    home: ExternalView(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home(),
    );
  }
}

class ExternalView extends StatelessWidget {
  const ExternalView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('This is the external view.'),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  ExternalDisplay externalDisplay = ExternalDisplay();
  String state = "Unplugged";
  String resolution = "";

  void onDisplayChange(bool connecting) {
    setState(() {
      if (connecting) {
        state = "Plugged";
      } else {
        state = "Unplugged";
        resolution = "";
      }
    });
  }

  @override
  void initState() {
    super.initState();
    externalDisplay.addListener(onDisplayChange);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Display Example'),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text("External Monitor is $state"),
            ),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: TextButton(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: () async {
                  await externalDisplay.connect();
                  setState(() {
                    resolution =
                        "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px";
                  });
                },
                child: const Text("Connect"),
              ),
            ),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text(resolution),
            ),
          ],
        ),
      ),
    );
  }
}
```

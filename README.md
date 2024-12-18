# external_display

Flutter 外掛程式支援透過有線或無線連接連接到外部顯示器

Flutter plugin support for connecting to external displays through wired or wireless connections

## Getting Started

### iOS

如果 `external_display` 需要使用套件，請在 `AppDelegate.swift` 中加入以下程式碼：

If `external_display` requires the use packages, please add the following code to `AppDelegate.swift`:

```
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

  func registerGeneratedPlugin(controller:FlutterViewController) {
    GeneratedPluginRegistrant.register(with: controller)
  }
```

example: <https://github.com/GavinFu7/external_display/blob/main/example/ios/Runner/AppDelegate.swift>

### External display entry point `externalDisplayMain`
```
@pragma('vm:entry-point')
void externalDisplayMain() {
}
```

### Create `externalDisplay` variables
```
ExternalDisplay externalDisplay = ExternalDisplay();
```

### Monitor external monitor plugging and unplugging
```
externalDisplay.addListener(onDisplayChange);
```

### Cancel monitoring of external monitor
```
externalDisplay.removeListener(onDisplayChange);
```

### Get the plugging status
```
externalDisplay.isPlugging
```

### Get the external monitor resolution
```
externalDisplay.resolution
```

### Connecting the monitor
```
await externalDisplay.connect();
```
or
```
await externalDisplay.connect(routeName: name);
```

## main view transfer parameters

### Add receive parameters listener
Receive parameters from external view
```
transferParameters.addListener(({required action, value}) {
  print(action);
  print(value);
});
```

Remove receive parameters listener
```
transferParameters.removeListener(receive);
```

### Transfer parameters to external view
```
await externalDisplay.sendParameters(action: actionName, value: parameters);
```

### waiting external monitor receive parameters ready

連接外接顯示器後，如果需要立即傳送參數，則需要使用 `waitingTransferParametersReady` 來確保外接顯示器可以接收參數。

After connecting an external monitor, if you need to transfer parameters immediately, you need to use `waitingTransferParametersReady` to ensure that the external monitor can receive the parameters.

```
externalDisplay.connect();
externalDisplay.waitingTransferParametersReady(
  onReady: () {
    print("Transfer parameters ready, transfer data!");
    externalDisplay.transferParameters(action: "action", value: "data");
  },
  onError: () { // 等候超過時間 waiting timeout
    print("Transfer parameters fail!");
  }
);
```

## external view transfer parameters

### include `transfer_parameters.dart`
```
import 'package:external_display/transfer_parameters.dart';
```

### Create `transferParameters` variables
```
TransferParameters transferParameters = TransferParameters();
```

### Add receive parameters listener
Receive parameters from main view
```
transferParameters.addListener(({required action, value}) {
  print(action);
  print(value);
});
```

Remove receive parameters listener
```
transferParameters.removeListener(receive);
```

## Transfer parameters to main view
```
await transferParameters.sendParameters(action: actionName, value: parameters);
```

## example
```
import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(
    home: externalView(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home()
    );
  }
}

class externalView extends StatelessWidget {
  const externalView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('This is external view.')),
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
  String state = "Unplug";
  String resolution = "";

  onDisplayChange(connecting) {
    if (connecting) {
      setState(() {
        state = "Plug";
      });
    } else {
      setState(() {
        state = "Unplug";
        resolution = "";
      });
    }
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
              child: Text("External Monitor is $state")
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
                    resolution = "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px";
                  });
                },
                child: const Text("Connect")
              ),
            ),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text(resolution)
            )
          ]
        ),
      )
    );
  }
}
```
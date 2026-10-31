import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';
import 'external_display.dart';

void main() {
  // Entry point of the main app
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  // Entry point for the external display window
  runApp(const MaterialApp(onGenerateRoute: generateRoute));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set Home as the main page
    return const MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<String> screens = []; // screen info
  String state = "Unplug"; // External display state
  String resolution = ""; // External display resolution

  // Callback when external display status changes
  void onDisplayChange(bool connecting) {
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

  // Callback for receiving parameters from external display
  void receiveParameterListener({required String action, dynamic value}) {
    debugPrint("Main View receive parameter action: $action");
    debugPrint("Main View receive parameter value: $value");
  }

  @override
  void initState() {
    super.initState();
    externalDisplay.addStatusListener(onDisplayChange);
    externalDisplay.addReceiveParameterListener(receiveParameterListener);
  }

  @override
  void dispose() {
    // 全域 externalDisplay 活到 process 結束；此處只移除本頁 listener，
    // 避免 Widget 銷毀後仍被回呼。若整個 App 不再使用外接螢幕，可改呼叫
    // externalDisplay.dispose()。
    externalDisplay.removeStatusListener(onDisplayChange);
    externalDisplay.removeReceiveParameterListener(receiveParameterListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('External Display Example'),
        ),
        body: Container(
          color: Colors.white,
          child: Column(children: [
            // Show external display state
            Container(
                height: 70,
                alignment: Alignment.center,
                child: Text("External Monitor is $state")),
            // Show screen info
            Container(
                height: 70,
                alignment: Alignment.center,
                child: Text(screens.join(", "))),
            // Button to get screen info
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    screens = await externalDisplay.getScreen();
                    setState(() {});
                  },
                  child: const Text("Get Screen")),
            ),
            // Button to create external display window
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.createWindow(title: "Testing");
                  },
                  child: const Text("Create window")),
            ),
            // Button to connect to external display and send parameters
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    final connected = await externalDisplay.connect();
                    if (!connected) {
                      setState(() {
                        resolution = "";
                      });
                      return;
                    }
                    await externalDisplay.waitingTransferParametersReady(
                      onReady: () {
                        debugPrint("First transfer parameters ready!");
                        externalDisplay.sendParameters(
                          action: "testing",
                          value: {"c": "cat", "d": "dog"},
                        );
                      },
                      onError: () {
                        debugPrint("First transfer parameters fail!");
                      },
                    );
                    setState(() {
                      resolution =
                          "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px";
                    });
                  },
                  child: const Text("Connect")),
            ),
            // Button to connect to external display with routeName
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    final connected =
                        await externalDisplay.connect(routeName: "Testing");
                    setState(() {
                      resolution = connected
                          ? "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px"
                          : "";
                    });
                  },
                  child: const Text("Connect with route")),
            ),
            // Button to transfer parameters
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.sendParameters(
                        action: "testing", value: {"a": "apple", "b": "boy"});
                  },
                  child: const Text("Transfer parameters")),
            ),
            // Show resolution
            Container(
                height: 70,
                alignment: Alignment.center,
                child: Text(resolution))
          ]),
        ));
  }
}

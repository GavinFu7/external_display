import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';
import 'package:external_display/receive_parameters.dart';
import 'package:path_provider/path_provider.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  ReceiveParameters receiveParameters = ReceiveParameters();
  receiveParameters.addListener(({required action, value}) {
    print(action);
    print(value);
  });

  getApplicationDocumentsDirectory().then((path) {
    print(path.path);
  });

  return MaterialPageRoute(
      builder: (_) => Scaffold(
            body: Center(child: Text('The route name is: ${settings.name}')),
          ));
}

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(onGenerateRoute: generateRoute));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
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

  onDisplayChange(connecting) async {
    if (connecting) {
      state = "Plug";
      setState(() {});
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

    getApplicationDocumentsDirectory().then((path) {
      print(path.path);
    });

    externalDisplay.addStatusListener(onDisplayChange);
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
            Container(
                height: 100,
                alignment: Alignment.center,
                child: Text("External Monitor is $state")),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.connect();
                    externalDisplay.waitingTransferParametersReady(onReady: () {
                      print("First transfer parameters ready!");
                      externalDisplay.transferParameters(
                          action: "testing", value: {"c": "cat", "d": "dog"});
                    }, onError: () {
                      print("First transfer parameters fail!");
                    });
                    setState(() {
                      resolution =
                          "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px";
                    });
                  },
                  child: const Text("Connect")),
            ),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.connect(routeName: "Testing");
                    setState(() {
                      resolution =
                          "width:${externalDisplay.resolution?.width}px, height:${externalDisplay.resolution?.height}px";
                    });
                  },
                  child: const Text("Connect")),
            ),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.transferParameters(
                        action: "testing", value: {"a": "apple", "b": "boy"});
                  },
                  child: const Text("Transfer parameters")),
            ),
            Container(
                height: 100,
                alignment: Alignment.center,
                child: Text(resolution))
          ]),
        ));
  }
}

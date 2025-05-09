import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';
import 'external_view.dart';

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
  List<String> screens = [];
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
                height: 70,
                alignment: Alignment.center,
                child: Text("External Monitor is $state")),
            Container(
                height: 70,
                alignment: Alignment.center,
                child: Text(screens.join(", "))),
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    screens = await externalDisplay.getScreen();
                    setState(() {});
                  },
                  child: const Text("Get Screen")),
            ),  
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.createWindow(title: "Testing");
                  },
                  child: const Text("Create window")),
            ),  
            Container(
              height: 70,
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
                      externalDisplay.sendParameters(
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
              height: 70,
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
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () async {
                    await externalDisplay.sendParameters(
                        action: "testing", value: {"a": "apple", "b": "boy"});
                  },
                  child: const Text("Transfer parameters")),
            ),
            Container(
                height: 70,
                alignment: Alignment.center,
                child: Text(resolution))
          ]),
        ));
  }
}

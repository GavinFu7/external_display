import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  print("generateRoute: ${settings.name}");
  switch (settings.name) {
    case 'home':
      return MaterialPageRoute(builder: (_) => const Home());
    default:
      return MaterialPageRoute(
          builder: (_) => Scaffold(
                body: Center(
                    child: Text('No route defined for ${settings.name}')),
              ));
  }
}

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void externalDisplayMain() {
  runApp(const MaterialApp(
    onGenerateRoute: generateRoute
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: 'home',
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
                  print("connect");
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
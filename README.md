# external_display

Flutter plugin support for connecting to external displays through wired or wireless connections

https://github.com/GavinFu7/external_display

## Getting Started

###External display entry point `externalDisplayMain`
```
@pragma('vm:entry-point')
void externalDisplayMain() {
}
```

###Create `externalDisplay` variables
```
ExternalDisplay externalDisplay = ExternalDisplay();
```

###Monitor external monitor plugging and unplugging
```
externalDisplay.addListener(onDisplayChange);
```

###Cancel monitoring of external monitor
```
externalDisplay.addListener(onDisplayChange);
```

###Get the external monitor resolution
```
externalDisplay.resolution
```

###Connecting the monitor
```
externalDisplay.connect();
```
or
```
externalDisplay.connect(routeName: name);
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
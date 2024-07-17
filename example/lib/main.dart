import 'package:flutter/material.dart';
import 'package:external_display/external_display.dart';


Route<dynamic> generateRoute(RouteSettings settings) {
  print(settings.name);
  /*
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const DisplayManagerScreen());
    case 'presentation':
      return MaterialPageRoute(builder: (_) => const SecondaryScreen());
    default:
      return MaterialPageRoute(
          builder: (_) => Scaffold(
                body: Center(
                    child: Text('No route defined for ${settings.name}')),
              ));
  }
  */
  return MaterialPageRoute(builder: (_) => Scaffold(
      body: Center(
          child: Text('No route defined for ${settings.name}')),
    ));
}

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void secondaryDisplayMain() {
  print('second main');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ExternalDisplay externalDisplay = ExternalDisplay();

  onDisplayChange(connecting) {
    print('onDisplayChange: ${connecting}');
    externalDisplay.connect();
  }

  @override
  void initState() {
    super.initState();
    externalDisplay.addListener(onDisplayChange);
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: 'home',
    );
  }
}

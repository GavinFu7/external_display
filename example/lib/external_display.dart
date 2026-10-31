import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:path_provider/path_provider.dart';

/// Function to generate route for external display view
Route<dynamic> generateRoute(RouteSettings settings) {
  return MaterialPageRoute(
    builder: (_) => ExternalDisplayPage(routeName: settings.name),
  );
}

/// Owns [TransferParameters] and disposes it with the page lifecycle.
class ExternalDisplayPage extends StatefulWidget {
  /// Creates an external display page for [routeName].
  const ExternalDisplayPage({super.key, this.routeName});

  /// The route name shown on this page.
  final String? routeName;

  @override
  State<ExternalDisplayPage> createState() => _ExternalDisplayPageState();
}

class _ExternalDisplayPageState extends State<ExternalDisplayPage> {
  late final TransferParameters _transferParameters;

  void _onReceiveParameters({required String action, dynamic value}) {
    debugPrint("External View receive parameter action: $action");
    debugPrint("External View receive parameter value: $value");

    _transferParameters.sendParameters(
        action: "sendParameters", value: "form external view");
  }

  @override
  void initState() {
    super.initState();
    // 外接引擎請用獨立實例，勿共用主 isolate 的全域 transferParameters。
    _transferParameters = TransferParameters();
    _transferParameters.addListener(_onReceiveParameters);

    getApplicationDocumentsDirectory().then((path) {
      debugPrint(path.path);
    });
  }

  @override
  void dispose() {
    _transferParameters.removeListener(_onReceiveParameters);
    _transferParameters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('The route name is: ${widget.routeName}', style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold))),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:path_provider/path_provider.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  TransferParameters transferParameters = TransferParameters();
  transferParameters.addListener(({required action, value}) {
    print(action);
    print(value);

    transferParameters.sendParameters(
        action: "sendParameters", value: "form external view");
  });

  getApplicationDocumentsDirectory().then((path) {
    print(path.path);
  });

  return MaterialPageRoute(
      builder: (_) => Scaffold(
            body: Center(child: Text('The route name is: ${settings.name}')),
          ));
}

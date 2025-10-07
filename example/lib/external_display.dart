import 'package:flutter/material.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:path_provider/path_provider.dart';

// Function to generate route for external display view
Route<dynamic> generateRoute(RouteSettings settings) {
  // Create a TransferParameters instance for communication
  TransferParameters transferParameters = TransferParameters();

  // Add listener to receive parameters from main view
  transferParameters.addListener(({required action, value}) {
    debugPrint("External View receive parameter action: $action");
    debugPrint("External View receive parameter value: $value");

    // Send parameters back to main view
    transferParameters.sendParameters(
        action: "sendParameters", value: "form external view");
  });

  // Get application documents directory and print its path
  getApplicationDocumentsDirectory().then((path) {
    debugPrint(path.path);
  });

  // Return a MaterialPageRoute with a simple scaffold showing the route name
  return MaterialPageRoute(
      builder: (_) => Scaffold(
            body: Center(child: Text('The route name is: ${settings.name}')),
          ));
}

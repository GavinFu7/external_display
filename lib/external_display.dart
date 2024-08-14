import 'dart:async';
import 'package:flutter/services.dart';

// Provides the 'ExternalDisplay' method.
class ExternalDisplay {
  final List<Function(dynamic)> _listeners = [];
  StreamSubscription? _streamSubscription;
  bool _isPlugging = false;

  // external monitor resolution
  Size? _currentResolution;

  static const MethodChannel _displayController =
      MethodChannel('displayController');
  static const EventChannel _monitorStateListener =
      EventChannel('monitorStateListener');

  // Connect an external monitor and get the resolution
  Future connect({String? routeName}) async {
    final size = await _displayController
        .invokeMethod('connect', {"routeName": routeName});
    if (size != false) {
      _currentResolution = Size(size["width"], size["height"]);
    }
  }

  // get resolution
  Size? get resolution {
    return _currentResolution;
  }

  // plugging status
  bool get isPlugging {
    return _isPlugging;
  }

  // Send parameters to external display page
  Future<bool> transferParameters(
      {required String action, required dynamic value}) async {
    return await _displayController
        .invokeMethod('transferParameters', {"action": action, "value": value});
  }

  // Monitor external monitor plugging and unplugging
  void addListener(Function(dynamic) listener) {
    if (_listeners.isEmpty) {
      _streamSubscription =
          _monitorStateListener.receiveBroadcastStream().listen((event) {
        _isPlugging = event;
        for (var listener in _listeners) {
          listener(event);
        }
      });
    }
    _listeners.add(listener);
  }

  // Cancel monitoring of external monitor
  bool removeListener(Function listener) {
    final result = _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _streamSubscription?.cancel();
    }

    return result;
  }
}

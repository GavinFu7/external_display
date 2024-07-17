import 'dart:async';
import 'package:flutter/services.dart';

class ExternalDisplay {
  final List<Function (dynamic)> _listeners = [];
  StreamSubscription? _streamSubscription;
  Size? _currentResolution;
  static const MethodChannel _displayController = MethodChannel('displayController');
  static const EventChannel _monitorStateListener = EventChannel('monitorStateListener');

  void connect({String? routeName}) async {
    final size = await _displayController.invokeMethod('connect', {"routeName": routeName});
    if (size != false) {
      _currentResolution = size;
    }
  }

  Size? get resolution {
    return _currentResolution;
  }

  Future<List<String>> getSupportResolutions() async {
    return await _displayController.invokeMethod('getSupportResolutions');
  }

  void addListener(Function (dynamic) listener) {
    if (_listeners.isEmpty) {
      _streamSubscription = _monitorStateListener.receiveBroadcastStream().listen((event) {
        for (var listener in _listeners) {
          listener(event);
        }
      });
    }
    _listeners.add(listener);
  }
  
  bool removeListener(Function listener) {
    final result = _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _streamSubscription?.cancel();
    }

    return result;
  }

  void show() {

  }
}

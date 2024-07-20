import 'dart:async';
import 'package:flutter/services.dart';

class ExternalDisplay {
  final List<Function (dynamic)> _listeners = [];
  StreamSubscription? _streamSubscription;
  Size? _currentResolution;
  static const MethodChannel _displayController = MethodChannel('displayController');
  static const EventChannel _monitorStateListener = EventChannel('monitorStateListener');

  Future connect({String? routeName}) async {
    final size = await _displayController.invokeMethod('connect', {"routeName": routeName});
    if (size != false) {
      _currentResolution = Size(size["width"], size["height"]);
    }
  }

  Size? get resolution {
    return _currentResolution;
  }

  void addListener(Function (dynamic) listener) {
    if (_listeners.isEmpty) {
      _streamSubscription = _monitorStateListener.receiveBroadcastStream().listen((event) {
        if (event == false) {
          _currentResolution = null;
          for (var listener in _listeners) {
            listener(false);
          }
        } else {
          _currentResolution = Size(event["width"], event["height"]);
          for (var listener in _listeners) {
            listener(true);
          }
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

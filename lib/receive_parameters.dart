import 'dart:async';
import 'package:flutter/services.dart';

class ReceiveParameters {
  final List<Function ({required String action, dynamic value})> _listeners = [];
  StreamSubscription? _streamSubscription;
  static const EventChannel _receiveParametersListener = EventChannel('receiveParametersListener');

  void addListener(Function ({required String action, dynamic value}) listener) {
    if (_listeners.isEmpty) {
      _streamSubscription = _receiveParametersListener.receiveBroadcastStream().listen((event) {
        for (var listener in _listeners) {
          listener(action: event["action"], value: event["value"]);
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
}
import 'dart:async';
import 'package:flutter/services.dart';

/// Provides the 'ReceiveParameters' method.
class ReceiveParameters {
  final Set<Function({required String action, dynamic value})> _listeners = {};
  static const EventChannel _receiveParametersListener =
      EventChannel('receiveParametersListener');

  /// Initialize ReceiveParameters class
  ReceiveParameters() {
    /// add parameters listener
    StreamSubscription streamSubscription =
        _receiveParametersListener.receiveBroadcastStream().listen((event) {
      for (var listener in _listeners) {
        listener(action: event["action"], value: event["value"]);
      }
    });

    _finalizer.attach(this, streamSubscription);
  }

  static final _finalizer = Finalizer<StreamSubscription>((streamSubscription) {
    streamSubscription.cancel();
  });

  /// Monitor receiving parameters
  void addListener(Function({required String action, dynamic value}) listener) {
    _listeners.add(listener);
  }

  /// Cancel receiving parameters
  bool removeListener(Function listener) {
    final result = _listeners.remove(listener);

    return result;
  }
}

import 'dart:async';
import 'package:flutter/services.dart';

/// Provides the 'ExternalDisplay' method.
class ExternalDisplay {
  final Set<Function(dynamic)> _statusListeners = {};
  final Set<Function({required String action, dynamic value})>
      _receiveParameterListeners = {};
  bool _isPlugging = false;
  Size? _currentResolution;

  static const MethodChannel _displayController =
      MethodChannel('displayController');
  static const EventChannel _monitorStateListener =
      EventChannel('monitorStateListener');

  /// Initialize ExternalDisplay class
  ExternalDisplay() {
    StreamSubscription streamSubscription =
        _monitorStateListener.receiveBroadcastStream().listen((event) {
      if (event is bool) {
        if (_isPlugging != event) {
          _isPlugging = event;
          for (var listener in _statusListeners) {
            listener(event);
          }
        }
      } else {
        for (var listener in _receiveParameterListeners) {
          listener(action: event["action"], value: event["value"]);
        }
      }
    });

    _finalizer.attach(this, streamSubscription);
  }

  static final _finalizer = Finalizer<StreamSubscription>((streamSubscription) {
    streamSubscription.cancel();
  });

  /// Connect an external monitor and get the resolution
  Future connect({String? routeName}) async {
    final size = await _displayController
        .invokeMethod('connect', {"routeName": routeName});
    if (size != false) {
      _currentResolution = Size(size["width"], size["height"]);
    }
  }

  /// if external monitor receive parameters ready run...
  Future waitingTransferParametersReady(
      {required Function() onReady, Function()? onError}) async {
    final ready =
        await _displayController.invokeMethod('waitingTransferParametersReady');
    if (ready) {
      onReady();
    } else if (onError != null) {
      onError();
    }
  }

  /// get resolution
  Size? get resolution {
    return _currentResolution;
  }

  /// plugging status
  bool get isPlugging {
    return _isPlugging;
  }

  /// Send parameters to external display page
  Future<bool> transferParameters(
      {required String action, dynamic value}) async {
    return await _displayController
        .invokeMethod('transferParameters', {"action": action, "value": value});
  }

  /// Monitor external monitor plugging and unplugging
  void addStatusListener(Function(dynamic) listener) {
    _statusListeners.add(listener);
  }

  /// Cancel monitoring of external monitor
  bool removeStatusListener(Function listener) {
    final result = _statusListeners.remove(listener);

    return result;
  }

  /// Monitor receiving parameters
  void addReceiveParameterListener(
      Function({required String action, dynamic value}) listener) {
    _receiveParameterListeners.add(listener);
  }

  /// Cancel receiving parameters
  bool removeReceiveParameterListener(Function listener) {
    final result = _receiveParameterListeners.remove(listener);

    return result;
  }
}

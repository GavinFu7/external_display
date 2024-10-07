import 'dart:async';
import 'package:flutter/services.dart';

/// Provides the 'ExternalDisplay' method.
class ExternalDisplay {
  final Set<Function(dynamic)> _listeners = {};
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
      _isPlugging = event;
      for (var listener in _listeners) {
        listener(event);
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
  Future waitingTransferParameters(
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
  void addListener(Function(dynamic) listener) {
    _listeners.add(listener);
  }

  /// Cancel monitoring of external monitor
  bool removeListener(Function listener) {
    final result = _listeners.remove(listener);

    return result;
  }
}

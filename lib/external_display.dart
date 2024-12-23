import 'dart:async';
import 'package:flutter/services.dart';

/// 提供 'ExternalDisplay' method
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

  /// 初始化 ExternalDisplay class
  ExternalDisplay() {
    // 監控 swift 傳回的資料
    StreamSubscription streamSubscription =
        _monitorStateListener.receiveBroadcastStream().listen((event) {
      if (event is bool) {
        // 如果傳圖值是 Boolean, 是顯示器插拔的狀態
        if (_isPlugging != event) {
          _isPlugging = event;
          for (var listener in _statusListeners) {
            listener(event);
          }
        }
      } else {
        // 其他, 是外部顯示頁面傳回的參數
        for (var listener in _receiveParameterListeners) {
          listener(action: event["action"], value: event["value"]);
        }
      }
    });

    _finalizer.attach(this, streamSubscription);
  }

  // 如果 'ExternalDisplay' 不再可以使用
  static final _finalizer = Finalizer<StreamSubscription>((streamSubscription) {
    // 停止監控 swift 傳回的資料
    streamSubscription.cancel();
  });

  /// 連接外接顯示器並取得分辨率
  Future connect({String? routeName}) async {
    final size = await _displayController
        .invokeMethod('connect', {"routeName": routeName});
    if (size != false) {
      _currentResolution = Size(size["width"], size["height"]);
    }
  }

  /// 等候外部顯示器可以接收參數
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

  /// 取得外接顯示器的解像度
  Size? get resolution {
    return _currentResolution;
  }

  /// 取得顯示器插拔的狀態
  bool get isPlugging {
    return _isPlugging;
  }

  /// 發送參數到外部顯示頁面
  Future<bool> sendParameters({required String action, dynamic value}) async {
    return await _displayController
        .invokeMethod('sendParameters', {"action": action, "value": value});
  }

  /// 監控外接顯示器的插拔
  void addStatusListener(Function(dynamic) listener) {
    _statusListeners.add(listener);
  }

  /// 取消外接顯示器插拔的監控
  bool removeStatusListener(Function listener) {
    final result = _statusListeners.remove(listener);

    return result;
  }

  /// 監控接收參數
  void addReceiveParameterListener(
      Function({required String action, dynamic value}) listener) {
    _receiveParameterListeners.add(listener);
  }

  /// 取消接收參數
  bool removeReceiveParameterListener(Function listener) {
    final result = _receiveParameterListeners.remove(listener);

    return result;
  }
}

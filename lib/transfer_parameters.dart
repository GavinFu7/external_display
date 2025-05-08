import 'dart:async';
import 'package:flutter/services.dart';

/// 傳遞參數
final transferParameters = TransferParameters();

/// 提供 'TransferParameters' method.
class TransferParameters {
  final Set<Function({required String action, dynamic value})> _listeners = {};

  static const EventChannel _receiveParametersListener =
      EventChannel('receiveParametersListener');
  static const MethodChannel _sendParameters = MethodChannel('sendParameters');

  /// 初始化 TransferParameters class
  TransferParameters() {
    // 開始監控 swift 傳回的資料 - 是主頁面傳來的參數
    StreamSubscription streamSubscription =
        _receiveParametersListener.receiveBroadcastStream().listen((event) {
      for (var listener in _listeners) {
        listener(action: event["action"], value: event["value"]);
      }
    });

    _finalizer.attach(this, streamSubscription);
  }

  // 如果 'TransferParameters' 不再可以使用
  static final _finalizer = Finalizer<StreamSubscription>((streamSubscription) {
    // 停止監控 swift 傳回的資料
    streamSubscription.cancel();
  });

  /// 發送參數到主頁面
  Future<bool> sendParameters({required String action, dynamic value}) async {
    return await _sendParameters
        .invokeMethod('sendParameters', {"action": action, "value": value});
  }

  /// 監控接收參數
  void addListener(Function({required String action, dynamic value}) listener) {
    _listeners.add(listener);
  }

  /// 取消接收參數
  bool removeListener(Function listener) {
    final result = _listeners.remove(listener);

    return result;
  }
}

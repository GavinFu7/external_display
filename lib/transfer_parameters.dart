import 'package:flutter/services.dart';

import 'src/shared_event_channel.dart';

/// 傳遞參數
final transferParameters = TransferParameters();

/// Callback when parameters are received from the main view.
typedef TransferParametersListener = void Function({
  required String action,
  dynamic value,
});

/// 提供 'TransferParameters' method.
///
/// Use it only in the external display entrypoint (`externalDisplayMain`).
/// All instances in that isolate share one native subscription; disposing one
/// instance does not affect the others.
class TransferParameters {
  final Set<TransferParametersListener> _listeners = {};
  bool _isDisposed = false;

  static const EventChannel _receiveParametersListener =
      EventChannel('receiveParametersListener');
  static const MethodChannel _sendParameters = MethodChannel('sendParameters');
  static final SharedEventChannel<TransferParameters> _receiver =
      SharedEventChannel<TransferParameters>(
          _receiveParametersListener, _onReceiveEvent);

  /// 初始化 TransferParameters class
  TransferParameters() {
    // 開始監控原生端傳回的資料 - 是主頁面傳來的參數
    if (isSupportedPlatform) {
      _receiver.attach(this);
    }
  }

  static void _onReceiveEvent(Object? event) {
    if (event is! Map) {
      return;
    }
    final action = event["action"];
    if (action is! String) {
      return;
    }
    for (final transfer in _receiver.members) {
      notifyEach(transfer._listeners,
          (listener) => listener(action: action, value: event["value"]),
          'a TransferParameters listener');
    }
  }

  /// 是否已釋放資源
  bool get isDisposed => _isDisposed;

  /// Stops this instance's listeners; the native subscription shared with the
  /// other instances is cancelled once the last one is disposed.
  ///
  /// 全域 [transferParameters] 會活到 process 結束；自行 `new` 的實例
  /// （例如外接頁）應在不再使用時呼叫此方法。
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _receiver.detach(this);
    _listeners.clear();
  }

  /// 發送參數到主頁面
  Future<bool> sendParameters({required String action, dynamic value}) async {
    if (!isSupportedPlatform) {
      return false;
    }
    final result = await _sendParameters.invokeMethod<dynamic>(
      'sendParameters',
      {"action": action, "value": value},
    );
    return result == true;
  }

  /// 監控接收參數
  ///
  /// Listeners added after [dispose] are ignored.
  void addListener(TransferParametersListener listener) {
    if (!_isDisposed) {
      _listeners.add(listener);
    }
  }

  /// 取消接收參數
  bool removeListener(TransferParametersListener listener) {
    return _listeners.remove(listener);
  }
}

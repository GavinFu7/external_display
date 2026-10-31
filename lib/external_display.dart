import 'dart:async';
import 'package:flutter/services.dart';

/// 外接顯示器
final externalDisplay = ExternalDisplay();

/// Callback when an external display is plugged (`true`) or unplugged (`false`).
typedef ExternalDisplayStatusListener = void Function(bool connecting);

/// Callback when parameters are received from the external view.
typedef ExternalDisplayParameterListener = void Function({
  required String action,
  dynamic value,
});

/// 提供 'ExternalDisplay' method
class ExternalDisplay {
  final Set<ExternalDisplayStatusListener> _statusListeners = {};
  final Set<ExternalDisplayParameterListener> _receiveParameterListeners = {};
  bool _isPlugging = false;
  Size? _currentResolution;
  StreamSubscription<dynamic>? _streamSubscription;
  bool _isDisposed = false;

  static const MethodChannel _displayController =
      MethodChannel('displayController');
  static const EventChannel _monitorStateListener =
      EventChannel('monitorStateListener');

  /// 初始化 ExternalDisplay class
  ExternalDisplay() {
    // 監控原生端傳回的資料
    _streamSubscription =
        _monitorStateListener.receiveBroadcastStream().listen((event) {
      if (event is bool) {
        // 如果傳回值是 Boolean, 是顯示器插拔的狀態
        if (_isPlugging != event) {
          _isPlugging = event;
          for (var listener in _statusListeners) {
            listener(event);
          }
        }
      } else if (event is Map) {
        // 其他, 是外部顯示頁面傳回的參數
        for (var listener in _receiveParameterListeners) {
          listener(action: event["action"] as String, value: event["value"]);
        }
      }
    });

    _finalizer.attach(this, _streamSubscription!, detach: this);
  }

  /// 如果 'ExternalDisplay' 不再可以使用
  static final _finalizer =
      Finalizer<StreamSubscription<dynamic>>((streamSubscription) {
    // 停止監控原生端傳回的資料
    streamSubscription.cancel();
  });

  /// 是否已釋放資源
  bool get isDisposed => _isDisposed;

  /// 取消 EventChannel 訂閱並清除所有 listener。
  ///
  /// 全域 [externalDisplay] 會活到 process 結束，若不再需要監聽插拔／參數，
  /// 應呼叫此方法；僅移除單一 listener 時請用 [removeStatusListener] /
  /// [removeReceiveParameterListener]。
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _finalizer.detach(this);
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _statusListeners.clear();
    _receiveParameterListeners.clear();
  }

  /// 取得顯示器列表
  Future<List<String>> getScreen() async {
    final screens = await _displayController.invokeMethod<List<dynamic>>('getScreen');
    return screens?.cast<String>() ?? const <String>[];
  }

  /// 建立外接顯示器頁面, 只供 macOS 使用。
  ///
  /// Returns `true` when the native side reports success.
  Future<bool> createWindow({
    String? title,
    bool? fullscreen,
    int? width,
    int? height,
    int? targetScreen,
  }) async {
    final result = await _displayController.invokeMethod<dynamic>(
      'createWindow',
      {
        "title": title,
        "fullscreen": fullscreen,
        "width": width,
        "height": height,
        "targetScreen": targetScreen,
      },
    );
    return result == true;
  }

  /// 銷毀外接顯示器頁面, 只供 macOS 使用。
  ///
  /// Returns `true` when a window was destroyed.
  Future<bool> destroyWindow() async {
    final result =
        await _displayController.invokeMethod<dynamic>('destroyWindow');
    if (result == true) {
      _currentResolution = null;
    }
    return result == true;
  }

  /// 連接外接顯示器並取得分辨率。
  ///
  /// Returns `true` when connected and [resolution] was updated; otherwise
  /// `false` and [resolution] is cleared.
  Future<bool> connect({String? routeName, int? targetScreen}) async {
    final size = await _displayController.invokeMethod<dynamic>(
      'connect',
      {"routeName": routeName, "targetScreen": targetScreen},
    );
    if (size is Map) {
      final width = size["width"];
      final height = size["height"];
      if (width is num && height is num) {
        _currentResolution = Size(width.toDouble(), height.toDouble());
        return true;
      }
    }
    _currentResolution = null;
    return false;
  }

  /// 斷開外接顯示器。
  ///
  /// Returns `true` when the native side reports success.
  Future<bool> disconnect({String? routeName}) async {
    final result = await _displayController.invokeMethod<dynamic>(
      'disconnect',
      {"routeName": routeName},
    );
    if (result == true) {
      _currentResolution = null;
    }
    return result == true;
  }

  /// 等候外部顯示器可以接收參數。
  ///
  /// Returns `true` when ready. Optional [onReady] / [onError] callbacks are
  /// invoked for convenience.
  Future<bool> waitingTransferParametersReady({
    VoidCallback? onReady,
    VoidCallback? onError,
  }) async {
    final ready = await _displayController
            .invokeMethod<dynamic>('waitingTransferParametersReady') ==
        true;
    if (ready) {
      onReady?.call();
    } else {
      onError?.call();
    }
    return ready;
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
    final result = await _displayController.invokeMethod<dynamic>(
      'sendParameters',
      {"action": action, "value": value},
    );
    return result == true;
  }

  /// 監控外接顯示器的插拔
  void addStatusListener(ExternalDisplayStatusListener listener) {
    _statusListeners.add(listener);
  }

  /// 取消外接顯示器插拔的監控
  bool removeStatusListener(ExternalDisplayStatusListener listener) {
    return _statusListeners.remove(listener);
  }

  /// 監控接收參數
  void addReceiveParameterListener(ExternalDisplayParameterListener listener) {
    _receiveParameterListeners.add(listener);
  }

  /// 取消接收參數
  bool removeReceiveParameterListener(
      ExternalDisplayParameterListener listener) {
    return _receiveParameterListeners.remove(listener);
  }
}

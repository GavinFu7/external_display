import 'dart:async';
import 'package:flutter/services.dart';

import 'src/shared_event_channel.dart';

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
///
/// All instances in an isolate share one native subscription and the plug
/// state; disposing one instance does not affect the others.
class ExternalDisplay {
  final Set<ExternalDisplayStatusListener> _statusListeners = {};
  final Set<ExternalDisplayParameterListener> _receiveParameterListeners = {};
  // Shared by every instance: the last plug state the platform reported.
  static bool _isPlugging = false;
  Size? _currentResolution;
  // Counts the unplug (`false`) events this instance received; [connect]
  // compares it across its call.
  int _unplugs = 0;
  bool _isDisposed = false;

  static const MethodChannel _displayController =
      MethodChannel('displayController');
  static const EventChannel _monitorStateListener =
      EventChannel('monitorStateListener');

  // While no instance is live nothing observes the display, so the plug state
  // is forgotten until the platform reports it again: Android and iOS report
  // an attached display right after a listen, macOS when a window is created
  // or closed.
  static final SharedEventChannel<ExternalDisplay> _monitor =
      SharedEventChannel<ExternalDisplay>(
    _monitorStateListener,
    _onMonitorEvent,
    onStop: () => _isPlugging = false,
  );

  /// 初始化 ExternalDisplay class
  ExternalDisplay() {
    // 監控原生端傳回的資料
    if (isSupportedPlatform) {
      _monitor.attach(this);
      if (_isPlugging) {
        // On Android and iOS each instance used to receive the native initial
        // `true` after its own listen. The shared subscription already had
        // it, so repeat it once for this instance unless it is disposed or
        // unplugged first.
        scheduleMicrotask(() {
          if (!_isDisposed && _isPlugging) {
            notifyEach(_statusListeners, (listener) => listener(true),
                'an ExternalDisplay status listener');
          }
        });
      }
    }
  }

  static void _onMonitorEvent(Object? event) {
    if (event is bool) {
      // 如果傳回值是 Boolean, 是顯示器插拔的狀態
      if (!event) {
        for (final display in _monitor.members) {
          display._currentResolution = null;
          display._unplugs++;
        }
      }
      if (_isPlugging != event) {
        _isPlugging = event;
        for (final display in _monitor.members) {
          notifyEach(display._statusListeners, (listener) => listener(event),
              'an ExternalDisplay status listener');
        }
      }
    } else if (event is Map) {
      // 其他, 是外部顯示頁面傳回的參數
      final action = event["action"];
      if (action is! String) {
        return;
      }
      for (final display in _monitor.members) {
        notifyEach(display._receiveParameterListeners,
            (listener) => listener(action: action, value: event["value"]),
            'an ExternalDisplay parameter listener');
      }
    }
  }

  /// Calls [method] on the native side, or returns `null` without touching
  /// the channel on a platform the plugin does not support.
  static Future<T?> _invoke<T>(String method, [dynamic arguments]) async {
    if (!isSupportedPlatform) {
      return null;
    }
    return _displayController.invokeMethod<T>(method, arguments);
  }

  /// 是否已釋放資源
  bool get isDisposed => _isDisposed;

  /// Stops this instance's listeners; the native subscription shared with the
  /// other instances is cancelled once the last one is disposed, and the
  /// shared [isPlugging] is reset.
  ///
  /// 全域 [externalDisplay] 會活到 process 結束，若不再需要監聽插拔／參數，
  /// 應呼叫此方法；僅移除單一 listener 時請用 [removeStatusListener] /
  /// [removeReceiveParameterListener]。
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _monitor.detach(this);
    _statusListeners.clear();
    _receiveParameterListeners.clear();
  }

  /// 取得顯示器列表
  Future<List<String>> getScreen() async {
    final screens = await _invoke<List<dynamic>>('getScreen');
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
    final result = await _invoke<dynamic>(
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
        await _invoke<dynamic>('destroyWindow');
    if (result == true) {
      _currentResolution = null;
    }
    return result == true;
  }

  /// 連接外接顯示器並取得分辨率。
  ///
  /// Returns `true` when connected and [resolution] was updated; otherwise
  /// `false` and [resolution] is cleared.
  ///
  /// An unplug (`false` status event) that reaches this instance while the
  /// call is in flight ends the session it would report: the call then
  /// returns `false` and leaves [resolution] cleared, whatever the native side
  /// answered. On iOS the status event of a session that ends right after
  /// connecting can reach Dart before the connect result sent earlier.
  Future<bool> connect({String? routeName, int? targetScreen}) async {
    final unplugsBefore = _unplugs;
    final size = await _invoke<dynamic>(
      'connect',
      {"routeName": routeName, "targetScreen": targetScreen},
    );
    if (_unplugs == unplugsBefore && size is Map) {
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
    final result = await _invoke<dynamic>(
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
    final ready =
        await _invoke<dynamic>('waitingTransferParametersReady') == true;
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

  /// Whether [connect] succeeded on this instance and neither [disconnect],
  /// [destroyWindow], a failed [connect] nor an unplug seen before [dispose]
  /// has cleared it since: `true` exactly while [resolution] is set.
  bool get isConnected => _currentResolution != null;

  /// 取得顯示器插拔的狀態
  bool get isPlugging {
    return _isPlugging;
  }

  /// 發送參數到外部顯示頁面
  Future<bool> sendParameters({required String action, dynamic value}) async {
    final result = await _invoke<dynamic>(
      'sendParameters',
      {"action": action, "value": value},
    );
    return result == true;
  }

  /// 監控外接顯示器的插拔
  ///
  /// If [isPlugging] is already `true` when this instance is created,
  /// listeners added synchronously right after construction receive `true`
  /// once; a listener added later (for example after an `await`) should read
  /// [isPlugging] instead. Listeners added after [dispose] are ignored.
  void addStatusListener(ExternalDisplayStatusListener listener) {
    if (!_isDisposed) {
      _statusListeners.add(listener);
    }
  }

  /// 取消外接顯示器插拔的監控
  bool removeStatusListener(ExternalDisplayStatusListener listener) {
    return _statusListeners.remove(listener);
  }

  /// 監控接收參數
  ///
  /// Listeners added after [dispose] are ignored.
  void addReceiveParameterListener(ExternalDisplayParameterListener listener) {
    if (!_isDisposed) {
      _receiveParameterListeners.add(listener);
    }
  }

  /// 取消接收參數
  bool removeReceiveParameterListener(
      ExternalDisplayParameterListener listener) {
    return _receiveParameterListeners.remove(listener);
  }
}

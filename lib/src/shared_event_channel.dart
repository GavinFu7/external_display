import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the plugin has a native side on the current platform.
///
/// Read on every call, so tests can set [debugDefaultTargetPlatformOverride].
bool get isSupportedPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// One subscription to an [EventChannel], shared by every attached member in
/// this isolate.
///
/// [EventChannel.receiveBroadcastStream] installs the channel's message
/// handler on each listen, and removes it and cancels the native stream on
/// any cancel. Separate subscriptions to one channel therefore steal each
/// other's events, and cancelling one of them silences all of them.
///
/// If the platform rejects the first `listen`, Flutter reports the error
/// itself and the subscription is not retried while a member stays attached.
class SharedEventChannel<T extends Object> {
  /// Creates a shared subscription to a channel that passes every event to
  /// the given callback.
  ///
  /// `onStop` runs each time the native subscription is cancelled after the
  /// last member was detached.
  SharedEventChannel(this._channel, this._onEvent, {this._onStop});

  final EventChannel _channel;
  final void Function(Object? event) _onEvent;
  final VoidCallback? _onStop;
  final Set<T> _members = <T>{};
  StreamSubscription<dynamic>? _subscription;

  /// A copy of the attached members, safe to iterate while members change.
  List<T> get members => List<T>.of(_members);

  /// Attaches [member], starting the native subscription for the first one.
  void attach(T member) {
    _members.add(member);
    _subscription ??= _channel.receiveBroadcastStream().listen(_onEvent);
  }

  /// Detaches [member], cancelling the native subscription after the last one.
  void detach(T member) {
    if (_members.remove(member) && _members.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
      _onStop?.call();
    }
  }
}

/// Calls [notify] for every listener in a copy of [listeners].
///
/// As in [ChangeNotifier.notifyListeners], a listener removed by an earlier
/// one is skipped, and an exception thrown by a listener is reported to
/// [FlutterError.reportError] without stopping the others. [description]
/// names the listeners in that report.
void notifyEach<L>(
  Set<L> listeners,
  void Function(L listener) notify,
  String description,
) {
  for (final listener in List<L>.of(listeners)) {
    if (!listeners.contains(listener)) {
      continue;
    }
    try {
      notify(listener);
    } catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'external_display',
          context: ErrorDescription('while notifying $description'),
        ),
      );
    }
  }
}

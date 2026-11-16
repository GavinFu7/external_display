import 'package:external_display/external_display.dart';
import 'package:external_display/transfer_parameters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const displayController = MethodChannel('displayController');
  const sendParametersChannel = MethodChannel('sendParameters');
  const monitorStateListener = EventChannel('monitorStateListener');
  const receiveParametersListener = EventChannel('receiveParametersListener');

  late List<MethodCall> displayCalls;
  late List<MethodCall> sendParameterCalls;
  late MockStreamHandlerEventSink? monitorEvents;
  late int monitorListens;
  late int monitorCancels;

  setUp(() {
    displayCalls = <MethodCall>[];
    sendParameterCalls = <MethodCall>[];
    monitorEvents = null;
    monitorListens = 0;
    monitorCancels = 0;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockStreamHandler(
      monitorStateListener,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          monitorListens++;
          monitorEvents = events;
        },
        onCancel: (Object? arguments) => monitorCancels++,
      ),
    );
    messenger.setMockStreamHandler(
      receiveParametersListener,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {},
      ),
    );

    messenger.setMockMethodCallHandler(displayController, (MethodCall call) async {
      displayCalls.add(call);
      switch (call.method) {
        case 'getScreen':
          return <dynamic>['1. Screen A [1920x1080]'];
        case 'connect':
          return <String, double>{'width': 1920, 'height': 1080};
        case 'disconnect':
        case 'createWindow':
        case 'destroyWindow':
        case 'waitingTransferParametersReady':
        case 'sendParameters':
          return true;
      }
      return null;
    });

    messenger.setMockMethodCallHandler(sendParametersChannel, (MethodCall call) async {
      sendParameterCalls.add(call);
      return true;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(displayController, null);
    messenger.setMockMethodCallHandler(sendParametersChannel, null);
    messenger.setMockStreamHandler(monitorStateListener, null);
    messenger.setMockStreamHandler(receiveParametersListener, null);
  });

  // Sends [event] from the mocked native side and lets it reach the listeners.
  Future<void> emitMonitorEvent(Object? event) async {
    monitorEvents!.success(event);
    await pumpEventQueue();
  }

  // Collects errors sent to FlutterError.reportError for the current test.
  List<FlutterErrorDetails> captureFlutterErrors() {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    return errors;
  }

  test('getScreen returns cast string list', () async {
    final display = ExternalDisplay();
    addTearDown(display.dispose);

    expect(await display.getScreen(), ['1. Screen A [1920x1080]']);
    expect(displayCalls.single.method, 'getScreen');
  });

  test('connect updates resolution and returns true', () async {
    final display = ExternalDisplay();
    addTearDown(display.dispose);

    expect(
      await display.connect(routeName: 'externalView', targetScreen: 2),
      isTrue,
    );
    expect(display.resolution, const Size(1920, 1080));
    expect(displayCalls.single.method, 'connect');
    expect(
      displayCalls.single.arguments,
      {'routeName': 'externalView', 'targetScreen': 2},
    );
  });

  test('disconnect clears resolution', () async {
    final display = ExternalDisplay();
    addTearDown(display.dispose);

    await display.connect();
    expect(await display.disconnect(routeName: 'externalView'), isTrue);
    expect(display.resolution, isNull);
  });

  test('status listeners can be added and removed', () {
    final display = ExternalDisplay();
    addTearDown(display.dispose);

    var count = 0;
    void listener(bool connecting) => count++;

    display.addStatusListener(listener);
    expect(display.removeStatusListener(listener), isTrue);
    expect(display.removeStatusListener(listener), isFalse);
    expect(count, 0);
  });

  test('dispose is idempotent and marks disposed', () {
    final display = ExternalDisplay();
    display.dispose();
    display.dispose();
    expect(display.isDisposed, isTrue);
  });

  test('TransferParameters sendParameters uses sendParameters channel', () async {
    final transfer = TransferParameters();
    addTearDown(transfer.dispose);

    expect(
      await transfer.sendParameters(action: 'ping', value: {'ok': true}),
      isTrue,
    );
    expect(sendParameterCalls.single.method, 'sendParameters');
    expect(
      sendParameterCalls.single.arguments,
      {
        'action': 'ping',
        'value': {'ok': true},
      },
    );
  });

  group('shared subscription', () {
    test('two instances both receive a plug event', () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final second = ExternalDisplay();
      addTearDown(second.dispose);
      final firstEvents = <bool>[];
      final secondEvents = <bool>[];
      first.addStatusListener(firstEvents.add);
      second.addStatusListener(secondEvents.add);

      await emitMonitorEvent(true);

      expect(firstEvents, [true]);
      expect(secondEvents, [true]);
      expect(monitorListens, 1);
    });

    test('disposing one instance keeps the others subscribed', () async {
      final first = ExternalDisplay();
      final second = ExternalDisplay();
      addTearDown(second.dispose);
      final secondEvents = <bool>[];
      second.addStatusListener(secondEvents.add);

      first.dispose();
      await emitMonitorEvent(true);

      expect(secondEvents, [true]);
      expect(monitorCancels, 0);
    });

    test('disposing the last instance cancels once; a new one listens again',
        () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final second = ExternalDisplay();
      addTearDown(second.dispose);
      await emitMonitorEvent(true);
      first.dispose();
      second.dispose();
      await pumpEventQueue();
      expect(monitorCancels, 1);

      final third = ExternalDisplay();
      addTearDown(third.dispose);
      final events = <bool>[];
      third.addStatusListener(events.add);
      // The native side reports the plug state again after each listen.
      await emitMonitorEvent(true);

      expect(events, [true]);
      expect(monitorListens, 2);
    });

    test('an instance created while plugged reports isPlugging', () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      await emitMonitorEvent(true);

      final second = ExternalDisplay();
      addTearDown(second.dispose);

      expect(second.isPlugging, isTrue);
    });

    test('an instance created while plugged gets one initial true', () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final firstEvents = <bool>[];
      first.addStatusListener(firstEvents.add);
      await emitMonitorEvent(true);

      final second = ExternalDisplay();
      addTearDown(second.dispose);
      final secondEvents = <bool>[];
      second.addStatusListener(secondEvents.add);
      expect(secondEvents, isEmpty);
      await pumpEventQueue();

      expect(secondEvents, [true]);
      expect(firstEvents, [true]);
    });

    test('two instances created while plugged each get exactly one true',
        () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final firstEvents = <bool>[];
      first.addStatusListener(firstEvents.add);
      await emitMonitorEvent(true);

      final second = ExternalDisplay();
      addTearDown(second.dispose);
      final third = ExternalDisplay();
      addTearDown(third.dispose);
      final secondEvents = <bool>[];
      final thirdEvents = <bool>[];
      second.addStatusListener(secondEvents.add);
      third.addStatusListener(thirdEvents.add);
      await pumpEventQueue();

      expect(secondEvents, [true]);
      expect(thirdEvents, [true]);
      expect(firstEvents, [true]);
    });

    test('an instance disposed before its initial true never gets it',
        () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      await emitMonitorEvent(true);

      final second = ExternalDisplay();
      final secondEvents = <bool>[];
      second.addStatusListener(secondEvents.add);
      second.dispose();
      await pumpEventQueue();

      expect(secondEvents, isEmpty);
    });

    test('the first instance gets one true from the native initial event',
        () async {
      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final events = <bool>[];
      display.addStatusListener(events.add);

      await emitMonitorEvent(true);
      await pumpEventQueue();

      expect(events, [true]);
    });

    test('disposing the last instance forgets the plug state', () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      await emitMonitorEvent(true);
      expect(await first.connect(), isTrue);
      first.dispose();

      final second = ExternalDisplay();
      addTearDown(second.dispose);
      final events = <bool>[];
      second.addStatusListener(events.add);

      expect(second.isPlugging, isFalse);
      expect(second.isConnected, isFalse);
      // The resolution belongs to the instance that connected.
      expect(first.isConnected, isTrue);

      // The native side reports the plug state again after the new listen.
      await emitMonitorEvent(true);

      expect(second.isPlugging, isTrue);
      expect(events, [true]);
    });
  });

  group('dispatch', () {
    test('a status listener removing itself does not stop the next one',
        () async {
      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final calls = <String>[];
      void first(bool connecting) {
        calls.add('first');
        display.removeStatusListener(first);
      }

      display.addStatusListener(first);
      display.addStatusListener((connecting) => calls.add('second'));
      await emitMonitorEvent(true);

      expect(calls, ['first', 'second']);
    });

    test('a listener removed by an earlier listener is not called', () async {
      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final calls = <String>[];
      void second(bool connecting) => calls.add('second');
      display.addStatusListener((connecting) {
        calls.add('first');
        display.removeStatusListener(second);
      });
      display.addStatusListener(second);

      await emitMonitorEvent(true);

      expect(calls, ['first']);
    });

    test('a throwing listener is reported and does not stop the next one',
        () async {
      final errors = captureFlutterErrors();
      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final events = <bool>[];
      final parameters = <String>[];
      display.addStatusListener((connecting) => throw StateError('status'));
      display.addStatusListener(events.add);
      display.addReceiveParameterListener(
          ({required String action, dynamic value}) => throw StateError(action));
      display.addReceiveParameterListener(
          ({required String action, dynamic value}) => parameters.add(action));

      await emitMonitorEvent(true);
      await emitMonitorEvent(<String, Object?>{'action': 'ping'});

      expect(events, [true]);
      expect(parameters, ['ping']);
      expect(errors, hasLength(2));
      expect(errors.map((error) => error.library),
          everyElement('external_display'));
      expect(errors.map((error) => error.exception), everyElement(isStateError));
    });

    test('a parameter event without a String action is ignored', () async {
      final errors = captureFlutterErrors();
      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final received = <Object?>[];
      display.addReceiveParameterListener(
          ({required String action, dynamic value}) => received.add(value));

      await emitMonitorEvent(<String, Object?>{'action': null, 'value': 1});
      await emitMonitorEvent(<String, Object?>{'action': 7, 'value': 2});
      await emitMonitorEvent(<String, Object?>{'action': 'ping', 'value': 3});

      expect(received, [3]);
      expect(errors, isEmpty);
    });
  });

  group('connection state', () {
    test('connect sets resolution and isConnected on that instance only',
        () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final second = ExternalDisplay();
      addTearDown(second.dispose);

      expect(await first.connect(), isTrue);

      expect(first.isConnected, isTrue);
      expect(first.resolution, const Size(1920, 1080));
      expect(second.isConnected, isFalse);
      expect(second.resolution, isNull);

      expect(await second.disconnect(), isTrue);

      expect(first.isConnected, isTrue);
      expect(first.resolution, const Size(1920, 1080));
    });

    test('an unplug clears the resolution of every live instance', () async {
      final first = ExternalDisplay();
      addTearDown(first.dispose);
      final second = ExternalDisplay();
      addTearDown(second.dispose);
      await first.connect();
      await second.connect();
      await emitMonitorEvent(true);

      await emitMonitorEvent(false);

      expect(first.isConnected, isFalse);
      expect(first.resolution, isNull);
      expect(second.isConnected, isFalse);
      expect(second.resolution, isNull);
      expect(second.isPlugging, isFalse);
    });

    test('disconnect and destroyWindow clear isConnected', () async {
      final display = ExternalDisplay();
      addTearDown(display.dispose);

      await display.connect();
      expect(display.isConnected, isTrue);
      await display.disconnect();
      expect(display.isConnected, isFalse);

      await display.connect();
      expect(display.isConnected, isTrue);
      await display.destroyWindow();
      expect(display.isConnected, isFalse);
    });
  });

  group('after dispose', () {
    test('adding a listener is ignored and methods still use the channel',
        () async {
      final display = ExternalDisplay();
      display.dispose();
      void status(bool connecting) {}
      void parameter({required String action, dynamic value}) {}

      display.addStatusListener(status);
      display.addReceiveParameterListener(parameter);

      expect(display.removeStatusListener(status), isFalse);
      expect(display.removeReceiveParameterListener(parameter), isFalse);
      expect(await display.getScreen(), ['1. Screen A [1920x1080]']);
      expect(displayCalls.single.method, 'getScreen');
    });
  });

  group('unsupported platform', () {
    test('construction and every method are silent no-ops', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final errors = captureFlutterErrors();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final traffic = <String>[];
      messenger.allMessagesHandler = (channel, handler, message) {
        traffic.add(channel);
        return handler?.call(message);
      };
      addTearDown(() => messenger.allMessagesHandler = null);

      final display = ExternalDisplay();
      addTearDown(display.dispose);
      final events = <Object?>[];
      display.addStatusListener(events.add);
      display.addReceiveParameterListener(
          ({required String action, dynamic value}) => events.add(action));
      var readyCalls = 0;
      var errorCalls = 0;

      expect(await display.getScreen(), isEmpty);
      expect(await display.createWindow(), isFalse);
      expect(await display.destroyWindow(), isFalse);
      expect(await display.connect(), isFalse);
      expect(await display.disconnect(), isFalse);
      expect(
        await display.waitingTransferParametersReady(
          onReady: () => readyCalls++,
          onError: () => errorCalls++,
        ),
        isFalse,
      );
      expect(await display.sendParameters(action: 'ping'), isFalse);
      // A platform message on the channel finds no handler to deliver it.
      await messenger.handlePlatformMessage(
        monitorStateListener.name,
        monitorStateListener.codec.encodeSuccessEnvelope(true),
        null,
      );
      await pumpEventQueue();

      expect(display.isConnected, isFalse);
      expect(readyCalls, 0);
      expect(errorCalls, 1);
      expect(events, isEmpty);
      expect(traffic, isEmpty);
      expect(monitorListens, 0);
      expect(errors, isEmpty);
    });
  });
}

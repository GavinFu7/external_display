import 'package:external_display/external_display.dart';
import 'package:external_display/transfer_parameters.dart';
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

  setUp(() {
    displayCalls = <MethodCall>[];
    sendParameterCalls = <MethodCall>[];

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockStreamHandler(
      monitorStateListener,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {},
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
}

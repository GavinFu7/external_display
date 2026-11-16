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

  group('ExternalDisplayInfo.fromMap', () {
    test('reads every field', () {
      final info = ExternalDisplayInfo.fromMap(<dynamic, dynamic>{
        'id': 2,
        'name': 'HDMI Screen',
        'width': 1920.0,
        'height': 1080.0,
        'isPrimary': false,
        'hasTouch': true,
      });

      expect(info.id, 2);
      expect(info.name, 'HDMI Screen');
      expect(info.width, 1920.0);
      expect(info.height, 1080.0);
      expect(info.isPrimary, isFalse);
      expect(info.hasTouch, isTrue);
    });

    test('keeps hasTouch null when it is null or absent', () {
      final base = <dynamic, dynamic>{
        'id': 0,
        'name': 'Built-in Screen',
        'width': 1080.0,
        'height': 2400.0,
        'isPrimary': true,
      };

      expect(ExternalDisplayInfo.fromMap(base).hasTouch, isNull);
      expect(
        ExternalDisplayInfo.fromMap({...base, 'hasTouch': null}).hasTouch,
        isNull,
      );
      expect(
        ExternalDisplayInfo.fromMap({...base, 'hasTouch': false}).hasTouch,
        isFalse,
      );
    });

    test('accepts int width and height', () {
      final info = ExternalDisplayInfo.fromMap(<dynamic, dynamic>{
        'id': 1,
        'name': '',
        'width': 1280,
        'height': 800,
        'isPrimary': false,
        'hasTouch': false,
      });

      expect(info.width, 1280.0);
      expect(info.height, 800.0);
      expect(info.width, isA<double>());
      expect(info.height, isA<double>());
    });
  });

  test('ExternalDisplayInfo has value equality and a readable toString', () {
    const a = ExternalDisplayInfo(
      id: 2,
      name: 'HDMI Screen',
      width: 1920,
      height: 1080,
      isPrimary: false,
      hasTouch: false,
    );
    const b = ExternalDisplayInfo(
      id: 2,
      name: 'HDMI Screen',
      width: 1920,
      height: 1080,
      isPrimary: false,
      hasTouch: false,
    );
    const unknownTouch = ExternalDisplayInfo(
      id: 2,
      name: 'HDMI Screen',
      width: 1920,
      height: 1080,
      isPrimary: false,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(unknownTouch));
    expect(
      a.toString(),
      'ExternalDisplayInfo(id: 2, name: HDMI Screen, width: 1920.0, '
      'height: 1080.0, isPrimary: false, hasTouch: false)',
    );
    expect(unknownTouch.toString(), contains('hasTouch: null'));
  });

  group('getDisplays', () {
    void answerGetDisplays(Object? answer) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(displayController, (MethodCall call) async {
            displayCalls.add(call);
            return call.method == 'getDisplays' ? answer : null;
          });
    }

    test('maps the native list', () async {
      answerGetDisplays(<dynamic>[
        <String, dynamic>{
          'id': 0,
          'name': 'Built-in Screen',
          'width': 1080.0,
          'height': 2400.0,
          'isPrimary': true,
          'hasTouch': true,
        },
        <String, dynamic>{
          'id': 2,
          'name': 'HDMI Screen',
          'width': 1920,
          'height': 1080,
          'isPrimary': false,
          'hasTouch': null,
        },
      ]);
      final display = ExternalDisplay();
      addTearDown(display.dispose);

      expect(await display.getDisplays(), const [
        ExternalDisplayInfo(
          id: 0,
          name: 'Built-in Screen',
          width: 1080,
          height: 2400,
          isPrimary: true,
          hasTouch: true,
        ),
        ExternalDisplayInfo(
          id: 2,
          name: 'HDMI Screen',
          width: 1920,
          height: 1080,
          isPrimary: false,
        ),
      ]);
      expect(displayCalls.single.method, 'getDisplays');
      expect(displayCalls.single.arguments, isNull);
    });

    test('returns an empty list when the native side answers false', () async {
      answerGetDisplays(false);
      final display = ExternalDisplay();
      addTearDown(display.dispose);

      expect(await display.getDisplays(), isEmpty);
    });

    test('skips entries that are not maps', () async {
      answerGetDisplays(<dynamic>[
        '0. Built-in Screen [1080x2400]',
        <String, dynamic>{
          'id': 2,
          'name': 'HDMI Screen',
          'width': 1920.0,
          'height': 1080.0,
          'isPrimary': false,
          'hasTouch': false,
        },
        null,
      ]);
      final display = ExternalDisplay();
      addTearDown(display.dispose);

      final displays = await display.getDisplays();
      expect(displays, hasLength(1));
      expect(displays.single.id, 2);
      expect(displays.single.hasTouch, isFalse);
    });
  });
}

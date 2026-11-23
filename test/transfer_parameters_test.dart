import 'package:external_display/transfer_parameters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sendParametersChannel = MethodChannel('sendParameters');
  const receiveParametersListener = EventChannel('receiveParametersListener');

  late List<MethodCall> sendParameterCalls;
  late MockStreamHandlerEventSink? receiverEvents;
  late int receiverListens;
  late int receiverCancels;

  setUp(() {
    sendParameterCalls = <MethodCall>[];
    receiverEvents = null;
    receiverListens = 0;
    receiverCancels = 0;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      receiveParametersListener,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          receiverListens++;
          receiverEvents = events;
        },
        onCancel: (Object? arguments) => receiverCancels++,
      ),
    );
    messenger.setMockMethodCallHandler(sendParametersChannel, (
      MethodCall call,
    ) async {
      sendParameterCalls.add(call);
      return true;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sendParametersChannel, null);
    messenger.setMockStreamHandler(receiveParametersListener, null);
  });

  // Sends [action] from the mocked native side and lets it reach the listeners.
  Future<void> emit(Object? action, [Object? value]) async {
    receiverEvents!.success(<String, Object?>{
      'action': action,
      'value': value,
    });
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

  // Returns a listener that records each action it receives in [actions].
  TransferParametersListener recordInto(List<String> actions) =>
      ({required String action, dynamic value}) => actions.add(action);

  group('shared subscription', () {
    test('two instances both receive a parameter event', () async {
      final first = TransferParameters();
      addTearDown(first.dispose);
      final second = TransferParameters();
      addTearDown(second.dispose);
      final firstActions = <String>[];
      final secondActions = <String>[];
      first.addListener(recordInto(firstActions));
      second.addListener(recordInto(secondActions));

      await emit('ping');

      expect(firstActions, ['ping']);
      expect(secondActions, ['ping']);
      expect(receiverListens, 1);
    });

    test('disposing one instance keeps the others subscribed', () async {
      final first = TransferParameters();
      final second = TransferParameters();
      addTearDown(second.dispose);
      final secondActions = <String>[];
      second.addListener(recordInto(secondActions));

      first.dispose();
      await emit('ping');

      expect(secondActions, ['ping']);
      expect(receiverCancels, 0);
    });

    test(
      'disposing the last instance cancels once; a new one listens again',
      () async {
        final first = TransferParameters();
        addTearDown(first.dispose);
        final second = TransferParameters();
        addTearDown(second.dispose);
        first.dispose();
        second.dispose();
        await pumpEventQueue();
        expect(receiverCancels, 1);

        final third = TransferParameters();
        addTearDown(third.dispose);
        final actions = <String>[];
        third.addListener(recordInto(actions));
        await emit('ping');

        expect(actions, ['ping']);
        expect(receiverListens, 2);
      },
    );
  });

  group('dispatch', () {
    test('a listener removing itself does not stop the next one', () async {
      final transfer = TransferParameters();
      addTearDown(transfer.dispose);
      final calls = <String>[];
      void first({required String action, dynamic value}) {
        calls.add('first');
        transfer.removeListener(first);
      }

      transfer.addListener(first);
      transfer.addListener(
        ({required String action, dynamic value}) => calls.add('second'),
      );
      await emit('ping');

      expect(calls, ['first', 'second']);
    });

    test(
      'a throwing listener is reported and does not stop the next one',
      () async {
        final errors = captureFlutterErrors();
        final transfer = TransferParameters();
        addTearDown(transfer.dispose);
        final actions = <String>[];
        transfer.addListener(
          ({required String action, dynamic value}) => throw StateError(action),
        );
        transfer.addListener(recordInto(actions));

        await emit('ping');

        expect(actions, ['ping']);
        expect(errors.single.exception, isStateError);
        expect(errors.single.library, 'external_display');
      },
    );

    test('an event without a String action is ignored', () async {
      final errors = captureFlutterErrors();
      final transfer = TransferParameters();
      addTearDown(transfer.dispose);
      final actions = <String>[];
      transfer.addListener(recordInto(actions));

      await emit(null);
      await emit(7);
      receiverEvents!.success('not a map');
      await emit('ping');

      expect(actions, ['ping']);
      expect(errors, isEmpty);
    });
  });

  group('after dispose', () {
    test('adding a listener is ignored and sending still works', () async {
      final transfer = TransferParameters();
      transfer.dispose();
      final listener = recordInto(<String>[]);

      transfer.addListener(listener);

      expect(transfer.removeListener(listener), isFalse);
      expect(await transfer.sendParameters(action: 'ping'), isTrue);
      expect(sendParameterCalls.single.method, 'sendParameters');
    });
  });

  group('unsupported platform', () {
    test('construction and sendParameters are silent no-ops', () async {
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

      final transfer = TransferParameters();
      addTearDown(transfer.dispose);
      final actions = <String>[];
      transfer.addListener(recordInto(actions));

      expect(await transfer.sendParameters(action: 'ping'), isFalse);
      // A platform message on the channel finds no handler to deliver it.
      await messenger.handlePlatformMessage(
        receiveParametersListener.name,
        receiveParametersListener.codec.encodeSuccessEnvelope(<String, Object?>{
          'action': 'ping',
        }),
        null,
      );
      await pumpEventQueue();

      expect(actions, isEmpty);
      expect(traffic, isEmpty);
      expect(receiverListens, 0);
      expect(errors, isEmpty);
    });
  });
}

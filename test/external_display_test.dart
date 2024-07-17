import 'package:flutter_test/flutter_test.dart';
import 'package:external_display/external_display.dart';
import 'package:external_display/external_display_platform_interface.dart';
import 'package:external_display/external_display_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockExternalDisplayPlatform
    with MockPlatformInterfaceMixin
    implements ExternalDisplayPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ExternalDisplayPlatform initialPlatform = ExternalDisplayPlatform.instance;

  test('$MethodChannelExternalDisplay is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelExternalDisplay>());
  });

  test('getPlatformVersion', () async {
    ExternalDisplay externalDisplayPlugin = ExternalDisplay();
    MockExternalDisplayPlatform fakePlatform = MockExternalDisplayPlatform();
    ExternalDisplayPlatform.instance = fakePlatform;

    expect(await externalDisplayPlugin.getPlatformVersion(), '42');
  });
}

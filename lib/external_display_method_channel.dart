import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'external_display_platform_interface.dart';

/// An implementation of [ExternalDisplayPlatform] that uses method channels.
class MethodChannelExternalDisplay extends ExternalDisplayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('external_display');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

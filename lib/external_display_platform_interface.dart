import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'external_display_method_channel.dart';

abstract class ExternalDisplayPlatform extends PlatformInterface {
  /// Constructs a ExternalDisplayPlatform.
  ExternalDisplayPlatform() : super(token: _token);

  static final Object _token = Object();

  static ExternalDisplayPlatform _instance = MethodChannelExternalDisplay();

  /// The default instance of [ExternalDisplayPlatform] to use.
  ///
  /// Defaults to [MethodChannelExternalDisplay].
  static ExternalDisplayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ExternalDisplayPlatform] when
  /// they register themselves.
  static set instance(ExternalDisplayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

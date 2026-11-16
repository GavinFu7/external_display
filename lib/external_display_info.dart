/// @docImport 'external_display.dart';
library;

import 'package:flutter/foundation.dart';

/// A display reported by [ExternalDisplay.getDisplays].
///
/// [hasTouch] is `true` or `false` when the platform can tell whether the
/// display has a touchscreen, and `null` when it cannot.
@immutable
class ExternalDisplayInfo {
  /// Creates display information.
  const ExternalDisplayInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
    this.hasTouch,
  });

  /// Reads one entry of the native `getDisplays` answer.
  ///
  /// Expects the keys `id`, `name`, `width`, `height`, `isPrimary` and
  /// `hasTouch`. A missing or null `name` reads as `''` and a missing or null
  /// `hasTouch` reads as `null`.
  factory ExternalDisplayInfo.fromMap(Map<dynamic, dynamic> map) {
    return ExternalDisplayInfo(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String? ?? '',
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      isPrimary: map['isPrimary'] as bool,
      hasTouch: map['hasTouch'] as bool?,
    );
  }

  /// The display's identifier: the display ID on Android and the screen's
  /// index on iOS and macOS.
  ///
  /// On Android and macOS it is the number [ExternalDisplay.getScreen] prints
  /// first, and it can be passed as `targetScreen` (to
  /// [ExternalDisplay.connect] on Android, to [ExternalDisplay.createWindow] on
  /// macOS). On iOS, [ExternalDisplay.connect] ignores `targetScreen`, and from
  /// iOS 27 [ExternalDisplay.getScreen] numbers scenes rather than screens, so
  /// its numbers can differ from [id].
  final int id;

  /// The display's name, or `''` when the platform has none.
  final String name;

  /// The display's width, in the unit [ExternalDisplay.connect] reports on
  /// this platform.
  final double width;

  /// The display's height, in the unit [ExternalDisplay.connect] reports on
  /// this platform.
  final double height;

  /// Whether this is the platform's main display: the default display on
  /// Android, the device's own screen on iOS, and the screen with the menu bar
  /// on macOS (which can be an external monitor).
  final bool isPrimary;

  /// Whether the display has a touchscreen: `true` or `false` when the
  /// platform can tell, `null` when it cannot.
  final bool? hasTouch;

  @override
  bool operator ==(Object other) {
    return other is ExternalDisplayInfo &&
        other.id == id &&
        other.name == name &&
        other.width == width &&
        other.height == height &&
        other.isPrimary == isPrimary &&
        other.hasTouch == hasTouch;
  }

  @override
  int get hashCode => Object.hash(id, name, width, height, isPrimary, hasTouch);

  @override
  String toString() {
    return 'ExternalDisplayInfo(id: $id, name: $name, width: $width, '
        'height: $height, isPrimary: $isPrimary, hasTouch: $hasTouch)';
  }
}

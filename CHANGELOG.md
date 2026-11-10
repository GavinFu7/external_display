## 0.5.3

### Fixed
- **Android**: Parse MethodChannel arguments as a `Map` instead of `JSONObject("${call.arguments}")`, which could fail at runtime because `Map.toString()` is not valid JSON.

### Changed
- Android plugin package/namespace renamed from `com.example.external_display` to `com.gavinfu.external_display`.
- `homepage` now points to the repository URL; iOS/macOS podspec metadata updated to match package version `0.5.3`.
- Bumps `flutter_lints` to `^6.0.0`.

## 0.5.2

### Fixed
- **macOS**: Exiting fullscreen on an external window no longer crashes the app (`Could not create the embedder backing store`). The main-window close observer now watches only the primary Flutter window, so AppKit transient windows created during fullscreen transitions no longer tear down the external `FlutterEngine`.

### Changed
- macOS external windows use a standard titled style mask with `fullScreenPrimary` collection behavior, and session teardown now calls `shutDownEngine()` after detaching the view.

## 0.5.1

### Added
- iOS Swift Package Manager support (`ios/external_display/Package.swift`).

### Changed
- Dart API return types are now explicit `Future<bool>` for `connect`, `disconnect`, `createWindow`, `destroyWindow`, `waitingTransferParametersReady`, and `sendParameters`.
- Status listener type is `void Function(bool connecting)`; parameter listeners use dedicated typedefs.
- Android/macOS tear down external sessions on unplug, reconnect, disconnect, and window close; external-view `sendParameters` completes its MethodChannel `result` on all platforms.
- Migrates Android plugin to built-in Kotlin (`kotlin.compilerOptions`) and raises the minimum Flutter SDK to 3.44 / Dart 3.12.

## 0.5.0

### Added
- **iOS 27 UISceneAccessory support**: On iOS 27+, external display content uses `UISceneAccessory.externalNonInteractive` and `ExternalDisplaySceneDelegate` instead of the legacy `UIWindow.screen` path.
- Example app adopts the Flutter UIScene lifecycle (`UIApplicationSceneManifest` + `FlutterPluginRegistrant`).

### Changed
- iOS `disconnect` and scene teardown now destroy the external `FlutterEngine` to avoid leaking a second Flutter runtime.
- External-view `sendParameters` now completes its MethodChannel `result`.

## 0.4.2

### Fixed
- Fixed abnormal display resolution issues after repeatedly connecting/disconnecting different external displays.

## 0.4.0

### Added
- **macOS support**: Now uses `createWindow` to create new windows for display projection on macOS.

### Changed
- **Simplified initialization**:  
  No longer need to explicitly declare:
  ```dart
  ExternalDisplay externalDisplay = ExternalDisplay();
  TransferParameters transferParameters = TransferParameters();
  ```

## 0.3.1

### Fixed
- Fixed an issue where popup dialogs from other Flutter plugins would incorrectly appear on external displays.

## 0.3.0

### Added
- **Bidirectional parameter transfer** between the main view and external display view.

## 0.2.1

### Fixed
- Disabled the plugin when iOS apps run on macOS to prevent the external display from overlapping the primary app window.

## 0.2.0

### Added
- Initial **Flutter plugin support** for external displays.

## 0.1.2

### Added
- `waitingTransferParametersReady` function to ensure parameter delivery synchronization after connecting an external display.  
  - Required when transferring parameters immediately upon connection.
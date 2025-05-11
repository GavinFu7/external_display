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
## 2.0.0

### BREAKING CHANGES:
- **Updated Dart SDK Version**: The library now requires a minimum Dart SDK version of 3.1.0 due to the use of the new `AppLifecycleListener` and its associated features. As a result, this update makes the library incompatible with Flutter versions below 3.13.0.

#### Improvements:
- **Enhanced Lifecycle Event Handling**: Improved the detection of app resume and pause events by implementing the new `AppLifecycleListener`.
- **New Callbacks**: Introduced several new callback methods to provide developers with more flexibility:
    - `onDetach`: Triggered when the app is detached from the view hierarchy.
    - `onExitRequested`: Triggered when an exit request is made for the app.
    - `onHide`: Triggered when the app's window becomes hidden.
    - `onInactive`: Triggered when the app enters an inactive state.
    - `onRestart`: Triggered when the app is restarted.
    - `onShow`: Triggered when the app's window becomes visible.
    - `onStateChange`: Callback for handling app lifecycle state changes, providing information about both the old and new app lifecycle states.
- **Mobile Testing Fix**: Included a fix for mobile testing that disables the duration of the visibility detector scan when in test mode. For web testing, you can enable this fix by setting the environment variable `TEST` to `true` using the `--dart-define=TEST=true` flag when running the `flutter run` command.

## 1.0.6

#### Improvements:
- Updated visibility_detector dependency to 0.4.0+2.
- Updated example project dependencies.

## 1.0.5

#### Documentation:
- Reorganized the content of the README into more concise and readable sections.
- Added usage examples and sample code to the "Usage" section.
- Added a "Contributing" section with instructions for those who want to contribute to the project.
- Added a "License" section with information about the MIT license.
- Added a "Installation" section with instructions for installing the library.
- Fixed a broken link in the "Example" section.

#### Improvements:
- Improved the changelog format to make it easier to read and understand.
- Added categories to the changelog to better organize the changes.

## 1.0.4

#### Documentation:
- Removed the divisor from changelog.

#### Bug Fixes:
- Fixed project formatter.

## 1.0.3

#### Documentation:
- Fixed the documentation of onFocus and onUnfocus events that were inverted.

## 1.0.2

#### Improvements:
- Downgrade of dart version from 2.18.6 to 2.12.0

## 1.0.1

#### Documentation:
- Updated pubspec description for pub.dev

## 1.0.0

## Initial release

#### Features:
- Created and updated the focus detection.
- Documentation and examples.
- Added tests.

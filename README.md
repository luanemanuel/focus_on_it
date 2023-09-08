<p align="center">
<img src="https://github.com/luanemanuel/focus_on_it/blob/master/assets/focus_on_it.png?raw=true" width="350" alt="Flutter Focus On It Package"/>
</p>

<p align="center">
	<a href="https://pub.dev/packages/focus_on_it"><img src="https://img.shields.io/pub/v/focus_on_it.svg" alt="Pub.dev Badge"></a>
	<a href="https://github.com/luanemanuel/focus_on_it/actions"><img src="https://github.com/luanemanuel/focus_on_it/workflows/test/badge.svg" alt="GitHub Build Badge"></a>
	<a href="https://github.com/tenhobi/effective_dart"><img src="https://img.shields.io/badge/style-effective_dart-40c4ff.svg" alt="Effective Dart Badge"></a>
	<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="MIT License Badge"></a>
	<a href="https://github.com/luanemanuel/focus_on_it/"><img src="https://img.shields.io/badge/platform-flutter-ff69b4.svg" alt="Flutter Platform Badge"></a>
</p>

Focus on It is a Dart library that allows you to get notified when a Flutter widget is focused or unfocused and react to it. 

It is a continuation of the [Focus Detector](https://pub.dev/packages/focus_detector) project, which is no longer maintained.

## About

Similar to the onResume()/onPause() methods on Android and the viewDidAppear()/viewDidDisappear() methods on iOS, Focus on It lets you know when a Flutter widget is focused or unfocused and gives you the opportunity to do something about it. You can use callbacks to get more control over your app and manage the events you want, such as:

- Pause a video when the user is not looking at it.
- Stop a camera preview when the user is not looking at it and start it again when the user looks at it.
- Turn off a resource-intensive feature when the user is not looking at it and turn it on again when the user looks at it.
- Sync data with an API when the user opens a screen.
- And much more!

## Installation

To install Focus on It, you can use either of the following methods:

### Method 1: flutter pub add
Use the flutter pub add command to install Focus on It:

```dart
flutter pub add focus_on_it
```

### Method 2: pubspec.yaml
Alternatively, you can add the following line to your pubspec.yaml file:

```dart
dependencies:
  focus_on_it: ^VERSION
```

Replace `VERSION` with the latest version of Focus on It. You can find the latest version on the [pub.dev page](https://pub.dev/packages/focus_on_it/).

Then, run flutter pub get to install the library.

Import the library into your code by adding the following line at the top of your file:

```dart
import 'package:focus_on_it/focus_on_it.dart';
```

## Events

Focus on It offers 13 events to help you manage your app:

- `onFocus`: Equivalent to `onResume()` on Android and `viewDidAppear()` on iOS. Triggered when the Flutter widget is focused after a route transition or when the widget is resumed from a paused state.
- `onUnfocus`: Equivalent to `onPause()` on Android and `viewDidDisappear()` on iOS. Triggered when the Flutter widget is unfocused after a route transition or when the widget is paused from a focused state.
- `onForegroundGained`: Triggered when the app is resumed from a paused state.
- `onForegroundLost`: Triggered when the app is paused from a resumed state.
- `onVisibilityGained`: Triggered when the Flutter widget is visible after a route transition.
- `onVisibilityLost`: Triggered when the Flutter widget is no longer visible after a route transition.
- `onDetach`: Triggered when the app is detached from the view hierarchy.
- `onExitRequested`: Triggered when an exit request is made for the app.
- `onHide`: Triggered when the app's window becomes hidden.
- `onInactive`: Triggered when the app enters an inactive state.
- `onRestart`: Triggered when the app is restarted.
- `onShow`: Triggered when the app's window becomes visible.
- `onStateChange`: Callback for handling app lifecycle state changes, providing information about both the old and new app lifecycle states.

## Usage

```dart
@override
Widget build(BuildContext context) =>
    FocusOnIt(
      onFocus: () {
        /// Equivalent to `onResume()` on Android and `viewDidAppear()` on iOS. 
        /// Triggered when the widget is focused after route transition or the widget resumed from a paused state.
        logger.i('Focus Gained.');
      },
      onUnfocus: () {
        /// Equivalent to `onPause()` on Android and `viewDidDisappear()` on iOS. 
        /// Triggered when the widget is unfocused after route transition or the widget paused from a focused state.
        logger.i('Focus Lost.');
      },
      onForegroundGained: () {
        /// Triggered when the app is resumed from a paused state.
        logger.i('Foreground Gained.');
      },
      onForegroundLost: () {
        /// Triggered when the app is paused from a resumed state.
        logger.i('Foreground Lost.');
      },
      onVisibilityGained: () {
        /// Triggered when the widget is visible after route transition.
        logger.i('Visibility Gained.');
      },
      onVisibilityLost: () {
        /// Triggered when the widget is no longer visible after route transition.
        logger.i('Visibility Lost.');
      },
      onDetach: () {
        /// Triggered when the widget is detached from the widget tree.
        logger.i('Detach.');
      },
      onExitRequested: () async {
        /// Triggered when the app is requested to exit.
        logger.i('Exit Requested.');
        return AppExitResponse.exit;
      },
      onHide: () {
        /// Triggered when the app is hidden.
        logger.i('Hide.');
      },
      onInactive: () {
        /// Triggered when the app is inactive.
        logger.i('Inactive.');
      },
      onRestart: () {
        /// Triggered when the app is restarted.
        logger.i('Restart.');
      },
      onShow: () {
        /// Triggered when the app is shown.
        logger.i('Show.');
      },
      onStateChange: (oldState, newState) {
        /// Triggered when the app state changes.
        logger.i('State Change: $oldState -> $newState');
      },
      child: const Placeholder(),
    );
```
## Testing

Please note that enabling the test environment variable (`TEST=true`) is only necessary when testing in a web environment. For iOS and Android, this configuration is automatically handled.

### Web Testing (if applicable)

1. **Set the test environment variable:**
    - To enable the testing fix in web environments, you can set the `TEST` environment variable to `true` when running the `flutter run` command. Use the following command:

      ```
      flutter test --dart-define=TEST=true {file}
      ```

2. **Run your tests**:
    - Now you can run your tests as usual to ensure that the behavior of the `FocusOnIt` package is as expected.

## Example

To see an example of how to use Focus on It, check out the following file in this repository:

- [Focus On It Example](https://github.com/luanemanuel/focus_on_it/tree/master/example)

## Contributing

We welcome contributions to the Focus on It project! If you would like to contribute, please feel free to reach out to the current maintainers for more information.

## Issues

If you encounter any issues while using Focus on It, please open a new issue in the [issue tracker](https://github.com/luanemanuel/focus_on_it/issues). Please include as much information as possible, such as the version of Focus on It you are using and steps to reproduce the issue.

## License

Focus on It is licensed under the MIT license. See [LICENSE](https://github.com/luanemanuel/focus_on_it/blob/master/LICENSE) for more information.

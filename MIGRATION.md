# Migrating to 3.0.0

I dropped `visibility_detector` and `universal_io` in 3.0.0, so a few constructor parameters had to change. Here's what you need to update when coming from 2.x.

## 1. Run `dart fix` to strip `focusKey`

`focusKey` isn't used anymore. Bump the version in your `pubspec.yaml`, grab the update, and let Dart remove it for you:

```sh
flutter pub upgrade focus_on_it
dart fix --apply
```

## 2. Move lifecycle callbacks into `appLifecycle`

Having 13+ callbacks directly on `FocusOnIt` was getting messy, so `onDetach`, `onExitRequested`, `onHide`, `onInactive`, `onRestart`, `onShow`, and `onStateChange` now live inside `FocusAppLifecycleCallbacks`.

Old (2.x):

```dart
FocusOnIt(
  focusKey: myKey,
  onFocus: () => playVideo(),
  onUnfocus: () => pauseVideo(),
  onHide: () => saveState(),
  onExitRequested: () async => AppExitResponse.exit,
  onStateChange: (oldState, newState) => debugPrint('$oldState -> $newState'),
  child: const MyPage(),
)
```

New (3.0.0):

```dart
FocusOnIt(
  onFocus: () => playVideo(),
  onUnfocus: () => pauseVideo(),
  appLifecycle: FocusAppLifecycleCallbacks(
    onHide: () => saveState(),
    onExitRequested: () async => AppExitResponse.exit,
    onStateChange: (oldState, newState) => debugPrint('$oldState -> $newState'),
  ),
  child: const MyPage(),
)
```

## 3. Add `viewport` if you're inside a scrollable list

Out of the box, `FocusOnIt` watches routes, tabs, `IndexedStack`, dialogs, and app background/foreground state. If your widget isn't inside a list, you don't need anything else.

If it's inside a `ListView`, `PageView`, or `CustomScrollView` and should react as you scroll it into view, pass `viewport`:

```dart
FocusOnIt(
  onFocus: () => playVideo(),
  onUnfocus: () => pauseVideo(),
  viewport: FocusViewportConfig(
    threshold: 0.6,
    minFocusDuration: const Duration(milliseconds: 250),
    onVisibilityChanged: (info) => debugPrint('${info.visibleFraction}'),
  ),
  child: const VideoCard(),
)
```

One nice side effect here: widgets taller than the screen used to get stuck in 2.x because they could never hit 100% visibility. Setting `threshold` fixes that completely.

## 4. Dialogs now take focus away by default

Opening a dialog or bottom sheet unfocuses the screen behind it, then focuses it again when the dialog closes. Want the old 2.x behavior? Pass `includeDialogs: false`:

```dart
FocusOnIt(
  includeDialogs: false,
  onFocus: () {},
  onUnfocus: () {},
  child: const MyPage(),
)
```

## 5. Delete the old test hacks

There's no 500ms timer left in the package, so you can delete `--dart-define=TEST=true` from your web test commands and rip out any `VisibilityDetectorController.instance.updateInterval = Duration.zero;` lines from your tests.

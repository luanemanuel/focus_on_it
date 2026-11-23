## 3.0.0-dev.2

### Bug Fixes
- **Hub lifecycle memory leak (`SharedLifecycleHub`):** moved hub tracking to `Expando<SharedLifecycleHub>` with lazy `AppLifecycleListener` attachment and a single persistent frame callback per binding, avoiding stale callback retention when all widgets unmount.
- **`triggerOnInit: false` + `viewport` race condition:** deferred initial setup completion until both route and first viewport measurements arrive, preventing unexpected initial `onFocus` callbacks.
- **Dwell timer visibility state sync:** kept `FocusStateMachine.isVisible` aligned with `state.isVisible` when backgrounded while a dwell timer is running, and preserved visibility across `viewport` enable transitions.
- **No post-frame `InheritedWidget` dependencies:** cached `FlutterView` inside `mount`/`didChangeDependencies` and switched fallback `MediaQuery` reads to non-subscribing lookups inside `ViewportVisibilityTracker`.
- **Build-phase safety & dynamic config updates:** deferred config/controller synchronization out of `didUpdateWidget`/`initState` into post-frame flushes, added dynamic `threshold` re-evaluation without scrolling, updated `FocusState` before firing `onVisibilityChanged`, and added `NaN`/`_disposed` re-entrancy guards.
- **`GlobalKey` reparenting & nested routes:** added `deactivate`/`activate` lifecycle handling across `FocusOnIt` and `ViewportVisibilityTracker`, matched innermost `ModalRoute` offstage nodes in nested `Navigator`s, and tracked `IndexedStack` children by `RenderObject` identity.

### Features
- **Configurable dwell on resume (`FocusViewportConfig.applyDwellOnResume`):** defaults to `false` for immediate resume when returning from background, with opt-in `true` for impression/analytics dwell behavior.
- **Non-scrollable clips, exact rotation geometry & paint-only animations:** `viewport` mode now intersects ancestor `describeApproximatePaintClip` bounds (`ClipRect`, `ClipRRect`, `ClipOval`, `ClipPath`), computes exact Sutherland-Hodgman polygon visibility for rotated/skewed targets, and re-measures on paint-only transforms (`SlideTransition`, `Transform.translate`).
- **Engine & runtime performance:** removed the per-widget `FocusOnItScope` wrapper in favor of lazy dependent tracking, switched `FocusOnIt` and viewport trackers to direct hub client interfaces (`SharedLifecycleClient` / `ViewportTrackerClient`), added shared per-`ScrollPosition` listener groups, reused per-frame ancestor scan/transform/clip/scrollable caches, and pooled common `const FocusState` snapshots.

### Documentation & Benchmarks
- Updated benchmark chart framing (`No 500ms timer`, neutral dialog scope pills, and direct scroll comparison between `3.0 (Viewport)` and `visibility_detector`).
- Streamlined `README.md` with cross-platform lifecycle notes and trade-offs, updated `example/pubspec.yaml`, added `library;` docs, and expanded engine/widget test suites.

## 3.0.0-dev.1

### BREAKING CHANGES
- **Zero external dependencies:** removed `visibility_detector` and `universal_io` completely.
- **Removed `focusKey`:** widget identity uses standard Flutter keys/state instead of a separate `Key` parameter. Run `dart fix --apply` to remove existing `focusKey` arguments automatically (via `lib/fix_data.yaml`).
- **Grouped lifecycle callbacks:** `onDetach`, `onExitRequested`, `onHide`, `onInactive`, `onRestart`, `onShow`, and `onStateChange` moved under `appLifecycle: FocusAppLifecycleCallbacks(...)`.
- **Dialogs unfocus by default:** `includeDialogs` defaults to `true`, unfocusing widgets behind translucent dialogs and bottom sheets (pass `includeDialogs: false` for 2.x behavior).
- **Updated constructor defaults & options:** added `controller`, `triggerOnInit` (default `true`), `notifyOnDispose` (default `false`), and `viewport: FocusViewportConfig(...)`. See `MIGRATION.md` for details.

### Features
- **Hybrid engine:** O(1) fast path driven by `ModalRoute`, `TickerMode`, `IndexedStack`/`Offstage`, and a shared `AppLifecycleListener` (`SharedLifecycleHub`).
- **Opt-in viewport visibility (`FocusViewportConfig`):** batched per-frame measurement via `ViewportVisibilityHub` supporting `threshold`, `minFocusDuration` dwell timer, and `onVisibilityChanged` with `FocusVisibilityInfo`.
- **Reactive state reading:** added `FocusOnItController` (`ValueNotifier<FocusState>`), `FocusOnIt.of(context)`, `FocusOnIt.maybeOf(context)`, `FocusOnIt.isFocusedOf(context)`, and `FocusOnIt.maybeIsFocusedOf(context)` powered by `InheritedModel`.
- **Zero test workarounds:** removed the 500ms timer and `--dart-define=TEST=true` requirement.

### Performance & Tooling
- Zero unnecessary subtree rebuilds when no descendant subscribes to `FocusOnIt.of` / `isFocusedOf`.
- Shared `AppLifecycleListener` and batched `ViewportVisibilityHub` with per-frame `Scrollable` rect caching.
- Upgraded static analysis to `package:very_good_analysis` with strict casts, inference, and raw types.
- Added automated `dart fix` rules, unit/widget test suite, modular `example/` app, and isolated benchmark suite.

## 2.0.1

#### Bug Fixes:
- Changed `dart:io` import to `universal_io` package to fix compatibility with Flutter Web.

## 2.0.0+1

#### Documentation:
- Minor fixes to the README.

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
- **Testing Fix**: Included a fix for mobile testing that disables the duration of the visibility detector scan when in test mode. For web testing, you can enable this fix by setting the environment variable `TEST` to `true` using the `--dart-define=TEST=true` flag when running the `flutter test` command.

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
- Added an "Installation" section with instructions for installing the library.
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

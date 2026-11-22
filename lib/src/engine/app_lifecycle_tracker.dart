import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';

/// Tracks application lifecycle transitions via [AppLifecycleListener].
class AppLifecycleTracker {
  /// Creates an [AppLifecycleTracker] bound to [binding] or the active binding.
  AppLifecycleTracker({
    required ValueChanged<bool> onForegroundChanged,
    FocusAppLifecycleCallbacks? callbacks,
    WidgetsBinding? binding,
  })  : _onForegroundChanged = onForegroundChanged,
        _callbacks = callbacks,
        _binding = binding ?? WidgetsBinding.instance {
    _lastState = _binding.lifecycleState;
    _isInForeground = _isForegroundState(_lastState);
    _listener = _createListener();
  }

  final ValueChanged<bool> _onForegroundChanged;
  final WidgetsBinding _binding;
  FocusAppLifecycleCallbacks? _callbacks;
  late AppLifecycleListener _listener;
  AppLifecycleState? _lastState;
  late bool _isInForeground;

  /// Whether the application is currently considered in the foreground.
  bool get isInForeground => _isInForeground;

  /// Updates the lifecycle callbacks, recreating the listener only if needed.
  void updateCallbacks(FocusAppLifecycleCallbacks? callbacks) {
    final hadExitHandler = _callbacks?.onExitRequested != null;
    final hasExitHandler = callbacks?.onExitRequested != null;
    _callbacks = callbacks;

    if (hadExitHandler != hasExitHandler) {
      _listener.dispose();
      _listener = _createListener();
    }
  }

  /// Releases the underlying [AppLifecycleListener].
  void dispose() {
    _listener.dispose();
  }

  AppLifecycleListener _createListener() {
    final onExitRequested = _callbacks?.onExitRequested;
    return AppLifecycleListener(
      binding: _binding,
      onResume: () => _setForeground(isInForeground: true),
      onPause: () => _setForeground(isInForeground: false),
      onHide: () {
        _setForeground(isInForeground: false);
        _callbacks?.onHide?.call();
      },
      onShow: () => _callbacks?.onShow?.call(),
      onInactive: () => _callbacks?.onInactive?.call(),
      onRestart: () => _callbacks?.onRestart?.call(),
      onDetach: () {
        _setForeground(isInForeground: false);
        _callbacks?.onDetach?.call();
      },
      onExitRequested:
          onExitRequested != null ? () => _callbacks!.onExitRequested!() : null,
      onStateChange: (state) {
        final oldState = _lastState;
        _lastState = state;
        _callbacks?.onStateChange?.call(oldState, state);
      },
    );
  }

  void _setForeground({required bool isInForeground}) {
    if (_isInForeground == isInForeground) return;
    _isInForeground = isInForeground;
    _onForegroundChanged(isInForeground);
  }

  static bool _isForegroundState(AppLifecycleState? state) {
    return switch (state) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        false,
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    };
  }
}

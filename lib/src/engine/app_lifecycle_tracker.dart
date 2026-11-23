import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/engine/shared_lifecycle_hub.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';

/// Tracks application lifecycle transitions via [SharedLifecycleHub].
class AppLifecycleTracker {
  /// Creates an [AppLifecycleTracker] bound to [binding] or the active binding.
  AppLifecycleTracker({
    required ValueChanged<bool> onForegroundChanged,
    FocusAppLifecycleCallbacks? callbacks,
    WidgetsBinding? binding,
  })  : _onForegroundChanged = onForegroundChanged,
        _callbacks = callbacks,
        _binding = binding ?? WidgetsBinding.instance {
    _hub = SharedLifecycleHub(_binding)
      ..subscribe(
        this,
        onForegroundChanged: _notifyForegroundChanged,
        getCallbacks: _getCallbacks,
      );
    _isInForeground = _hub.isInForeground;
    if (_callbacks?.onExitRequested != null) {
      _syncExitListener();
    }
  }

  final ValueChanged<bool> _onForegroundChanged;
  final WidgetsBinding _binding;
  late final SharedLifecycleHub _hub;
  FocusAppLifecycleCallbacks? _callbacks;
  AppLifecycleListener? _exitListener;
  late bool _isInForeground;

  /// Whether the application is currently considered in the foreground.
  bool get isInForeground => _isInForeground;

  /// Schedules [callback] on the shared post-frame route sync batch.
  void scheduleRouteSync(VoidCallback callback) =>
      _hub.scheduleRouteSync(callback);

  /// Cancels a pending post-frame route sync [callback].
  void cancelRouteSync(VoidCallback callback) => _hub.cancelRouteSync(callback);

  /// Registers [callback] to re-check ancestor visibility after frame builds.
  void addAncestorWatcher(VoidCallback callback) =>
      _hub.addAncestorWatcher(callback);

  /// Unregisters a previously registered ancestor visibility [callback].
  void removeAncestorWatcher(VoidCallback callback) =>
      _hub.removeAncestorWatcher(callback);

  /// Updates the lifecycle callbacks, managing an exit listener only when used.
  void updateCallbacks(FocusAppLifecycleCallbacks? callbacks) {
    _callbacks = callbacks;
    _syncExitListener();
  }

  /// Releases this tracker's subscription and optional exit listener.
  void dispose() {
    _exitListener?.dispose();
    _exitListener = null;
    _hub.unsubscribe(this);
  }

  FocusAppLifecycleCallbacks? _getCallbacks() => _callbacks;

  void _syncExitListener() {
    final wantsExitHandler = _callbacks?.onExitRequested != null;
    if (wantsExitHandler && _exitListener == null) {
      _exitListener = AppLifecycleListener(
        binding: _binding,
        onExitRequested: () => _callbacks!.onExitRequested!(),
      );
    } else if (!wantsExitHandler && _exitListener != null) {
      _exitListener?.dispose();
      _exitListener = null;
    }
  }

  void _notifyForegroundChanged(bool isInForeground) {
    if (_isInForeground == isInForeground) return;
    _isInForeground = isInForeground;
    _onForegroundChanged(isInForeground);
  }
}

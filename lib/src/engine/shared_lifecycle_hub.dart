import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';

/// Signature returning the current lifecycle callbacks for a subscriber.
typedef LifecycleCallbacksProvider = FocusAppLifecycleCallbacks? Function();

typedef _Subscriber = ({
  ValueChanged<bool> onForegroundChanged,
  LifecycleCallbacksProvider getCallbacks,
});

/// Shared [AppLifecycleListener] hub per [WidgetsBinding] to avoid allocating
/// one platform listener per `FocusOnIt` widget.
class SharedLifecycleHub {
  /// Returns the shared [SharedLifecycleHub] instance for [binding].
  factory SharedLifecycleHub(WidgetsBinding binding) {
    return _hubs.putIfAbsent(binding, () => SharedLifecycleHub._(binding));
  }

  SharedLifecycleHub._(this._binding) {
    _lastState = _binding.lifecycleState;
    _isInForeground = _isForegroundState(_lastState);
    _listener = AppLifecycleListener(
      binding: _binding,
      onResume: () => _setForeground(isInForeground: true),
      onPause: () => _setForeground(isInForeground: false),
      onHide: () {
        _setForeground(isInForeground: false);
        _dispatch((sub) => sub.getCallbacks()?.onHide?.call());
      },
      onShow: () => _dispatch((sub) => sub.getCallbacks()?.onShow?.call()),
      onInactive: () =>
          _dispatch((sub) => sub.getCallbacks()?.onInactive?.call()),
      onRestart: () =>
          _dispatch((sub) => sub.getCallbacks()?.onRestart?.call()),
      onDetach: () {
        _setForeground(isInForeground: false);
        _dispatch((sub) => sub.getCallbacks()?.onDetach?.call());
      },
      onStateChange: (state) {
        final oldState = _lastState;
        _lastState = state;
        _dispatch(
          (sub) => sub.getCallbacks()?.onStateChange?.call(oldState, state),
        );
      },
    );
  }

  static final Map<WidgetsBinding, SharedLifecycleHub> _hubs = {};

  final WidgetsBinding _binding;
  final Map<Object, _Subscriber> _subscribers = {};
  final Set<VoidCallback> _pendingRouteSyncs = {};
  final Set<VoidCallback> _ancestorWatchers = {};
  late final AppLifecycleListener _listener;
  AppLifecycleState? _lastState;
  late bool _isInForeground;
  bool _routeSyncFlushScheduled = false;
  bool _persistentFrameCallbackRegistered = false;

  /// Whether the application is currently considered in the foreground.
  bool get isInForeground => _isInForeground;

  /// Registers [callback] to be scheduled on frame updates while watching
  /// ancestors such as `IndexedStack` or `Offstage`.
  void addAncestorWatcher(VoidCallback callback) {
    _ancestorWatchers.add(callback);
    if (_persistentFrameCallbackRegistered) return;
    _persistentFrameCallbackRegistered = true;
    SchedulerBinding.instance
        .addPersistentFrameCallback(_handlePersistentFrame);
  }

  /// Unregisters an ancestor visibility [callback].
  void removeAncestorWatcher(VoidCallback callback) {
    _ancestorWatchers.remove(callback);
  }

  /// Enqueues [callback] to run once in the batched post-frame route sync.
  void scheduleRouteSync(VoidCallback callback) {
    _pendingRouteSyncs.add(callback);
    if (_routeSyncFlushScheduled) return;
    _routeSyncFlushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _flushRouteSyncs());
  }

  /// Cancels a previously queued route sync [callback].
  void cancelRouteSync(VoidCallback callback) {
    _pendingRouteSyncs.remove(callback);
  }

  /// Registers a subscriber keyed by [token].
  void subscribe(
    Object token, {
    required ValueChanged<bool> onForegroundChanged,
    required LifecycleCallbacksProvider getCallbacks,
  }) {
    _subscribers[token] = (
      onForegroundChanged: onForegroundChanged,
      getCallbacks: getCallbacks,
    );
  }

  /// Removes the subscriber identified by [token] and disposes when empty.
  void unsubscribe(Object token) {
    _subscribers.remove(token);
    if (_subscribers.isEmpty) {
      _pendingRouteSyncs.clear();
      _ancestorWatchers.clear();
      _listener.dispose();
      _hubs.remove(_binding);
    }
  }

  void _handlePersistentFrame(Duration _) {
    if (_ancestorWatchers.isEmpty) return;
    for (final callback in List<VoidCallback>.of(_ancestorWatchers)) {
      scheduleRouteSync(callback);
    }
  }

  void _flushRouteSyncs() {
    _routeSyncFlushScheduled = false;
    if (_pendingRouteSyncs.isEmpty) return;
    final callbacks = List<VoidCallback>.of(_pendingRouteSyncs);
    _pendingRouteSyncs.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void _setForeground({required bool isInForeground}) {
    if (_isInForeground == isInForeground) return;
    _isInForeground = isInForeground;
    _dispatch((sub) => sub.onForegroundChanged(isInForeground));
  }

  void _dispatch(void Function(_Subscriber subscriber) action) {
    for (final token in List<Object>.of(_subscribers.keys)) {
      final subscriber = _subscribers[token];
      if (subscriber != null) {
        action(subscriber);
      }
    }
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

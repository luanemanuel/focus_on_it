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
  late final AppLifecycleListener _listener;
  AppLifecycleState? _lastState;
  late bool _isInForeground;

  /// Whether the application is currently considered in the foreground.
  bool get isInForeground => _isInForeground;

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
      _listener.dispose();
      _hubs.remove(_binding);
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

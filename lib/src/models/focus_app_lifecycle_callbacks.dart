import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Granular application lifecycle callbacks for `AppLifecycleListener`.
@immutable
class FocusAppLifecycleCallbacks {
  /// Creates a [FocusAppLifecycleCallbacks] configuration.
  const FocusAppLifecycleCallbacks({
    this.onDetach,
    this.onExitRequested,
    this.onHide,
    this.onInactive,
    this.onRestart,
    this.onShow,
    this.onStateChange,
  });

  /// Called when the application is detached from the host view.
  final VoidCallback? onDetach;

  /// Called when the host asks the application to exit.
  final Future<AppExitResponse> Function()? onExitRequested;

  /// Called when the application window becomes hidden.
  final VoidCallback? onHide;

  /// Called when the application loses input focus or becomes inactive.
  final VoidCallback? onInactive;

  /// Called when the application is resumed from a hidden/paused state.
  final VoidCallback? onRestart;

  /// Called when the application window becomes visible.
  final VoidCallback? onShow;

  /// Called whenever the application lifecycle state transitions.
  final void Function(AppLifecycleState? oldState, AppLifecycleState newState)?
      onStateChange;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusAppLifecycleCallbacks &&
        other.onDetach == onDetach &&
        other.onExitRequested == onExitRequested &&
        other.onHide == onHide &&
        other.onInactive == onInactive &&
        other.onRestart == onRestart &&
        other.onShow == onShow &&
        other.onStateChange == onStateChange;
  }

  @override
  int get hashCode => Object.hash(
        onDetach,
        onExitRequested,
        onHide,
        onInactive,
        onRestart,
        onShow,
        onStateChange,
      );

  @override
  String toString() => 'FocusAppLifecycleCallbacks('
      'onDetach: ${onDetach != null}, '
      'onExitRequested: ${onExitRequested != null}, '
      'onHide: ${onHide != null}, '
      'onInactive: ${onInactive != null}, '
      'onRestart: ${onRestart != null}, '
      'onShow: ${onShow != null}, '
      'onStateChange: ${onStateChange != null})';
}

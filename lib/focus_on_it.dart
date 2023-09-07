library focus_on_it;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A widget that notifies when it is focused, unfocused, visible, or invisible.
class FocusOnIt extends StatefulWidget {
  /// A widget that notifies when a widget is focused or
  /// unfocused and react to it.
  const FocusOnIt({
    required this.child,
    this.focusKey,
    this.onFocus,
    this.onUnfocus,
    this.onVisibilityGained,
    this.onVisibilityLost,
    this.onForegroundGained,
    this.onForegroundLost,
    this.onDetach,
    this.onExitRequested,
    this.onHide,
    this.onInactive,
    this.onRestart,
    this.onShow,
    this.onStateChange,
    Key? key,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// The key to be used by the widget responsible for detect the
  /// visibility of the widget.
  final GlobalKey? focusKey;

  /// Equivalent to `onResume()` on Android and `viewDidAppear()` on iOS.
  /// Triggered when the widget is focused after route transition or the widget
  /// resumed from a paused state.
  final VoidCallback? onFocus;

  /// Equivalent to `onPause()` on Android and `viewDidDisappear()` on iOS.
  /// Triggered when the widget is unfocused after route transition or the
  /// widget paused from a focused state.
  final VoidCallback? onUnfocus;

  /// Triggered when the app is resumed from a paused state.
  final VoidCallback? onVisibilityGained;

  /// Triggered when the app is paused from a resumed state.
  final VoidCallback? onVisibilityLost;

  /// Triggered when the widget is visible after route transition.
  final VoidCallback? onForegroundGained;

  /// Triggered when the widget is no longer visible after route transition.
  final VoidCallback? onForegroundLost;

  final VoidCallback? onDetach;

  final Future<AppExitResponse> Function()? onExitRequested;

  final VoidCallback? onHide;

  final VoidCallback? onInactive;

  final VoidCallback? onRestart;

  final VoidCallback? onShow;

  final void Function(AppLifecycleState? oldState, AppLifecycleState newState)?
      onStateChange;

  @override
  State<FocusOnIt> createState() => _FocusOnItState();
}

class _FocusOnItState extends State<FocusOnIt> with WidgetsBindingObserver {
  late final GlobalKey _focusKey;
  late final AppLifecycleListener _appLifecycleListener;

  bool _isVisible = false;
  bool _isOnForeground = true;
  AppLifecycleState? _oldState;
  AppLifecycleState? _newState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusKey = widget.focusKey ?? GlobalKey();
    _appLifecycleListener = AppLifecycleListener(
      binding: WidgetsBinding.instance,
      onResume: _onResumed,
      onPause: _onPaused,
      onDetach: widget.onDetach,
      onExitRequested: widget.onExitRequested,
      onHide: widget.onHide,
      onInactive: widget.onInactive,
      onRestart: widget.onRestart,
      onShow: widget.onShow,
      onStateChange: (state) =>
          widget.onStateChange?.call(_oldState, _newState ?? state),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _oldState = _newState;
    _newState = state;
  }

  void _onResumed() {
    if (!_isVisible) return;

    if (!_isOnForeground) {
      _isOnForeground = true;
      _onFocus();
      _onForegroundGained();
    }
  }

  void _onPaused() {
    if (!_isVisible) return;

    if (_isOnForeground) {
      _isOnForeground = false;
      _onUnfocus();
      _onForegroundLost();
    }
  }

  /// Manages the visibility state.
  void _visibilityManager(double visibility) {
    if (!_isOnForeground) return;

    if (!_isVisible && visibility == 1) {
      _isVisible = true;
      _onFocus();
      _onVisibilityGained();
    } else if (_isVisible && visibility == 0) {
      _isVisible = false;
      _onUnfocus();
      _onVisibilityLost();
    }
  }

  /// Calls the onFocus callback.
  void _onFocus() => widget.onFocus?.call();

  /// Calls the onUnfocus callback.
  void _onUnfocus() => widget.onUnfocus?.call();

  /// Calls the onVisibilityGained callback.
  void _onVisibilityGained() => widget.onVisibilityGained?.call();

  /// Calls the onVisibilityLost callback.
  void _onVisibilityLost() => widget.onVisibilityLost?.call();

  /// Calls the onForegroundGained callback.
  void _onForegroundGained() => widget.onForegroundGained?.call();

  /// Calls the onForegroundLost callback.
  void _onForegroundLost() => widget.onForegroundLost?.call();

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _focusKey,
      onVisibilityChanged: (visibilityInfo) => _visibilityManager(
        visibilityInfo.visibleFraction,
      ),
      child: widget.child,
    );
  }
}

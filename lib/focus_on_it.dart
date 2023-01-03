library focus_on_it;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A widget that notifies when it is focused, unfocused, visible, or invisible.
class FocusOnIt extends StatefulWidget {
  const FocusOnIt({
    super.key,
    required this.child,
    this.onFocus,
    this.onUnfocus,
    this.onVisibilityGained,
    this.onVisibilityLost,
    this.onForegroundGained,
    this.onForegroundLost,
  });

  final Widget child;

  /// Equivalent to `onPause()` on Android and `viewDidDisappear()` on iOS.
  /// Triggered when the widget is unfocused after route transition or the
  /// widget paused from a focused state.
  final VoidCallback? onFocus;

  /// Equivalent to `onResume()` on Android and `viewDidAppear()` on iOS.
  /// Triggered when the widget is focused after route transition or the widget
  /// resumed from a paused state.
  final VoidCallback? onUnfocus;

  /// Triggered when the app is resumed from a paused state.
  final VoidCallback? onVisibilityGained;

  /// Triggered when the app is paused from a resumed state.
  final VoidCallback? onVisibilityLost;

  /// Triggered when the widget is visible after route transition.
  final VoidCallback? onForegroundGained;

  /// Triggered when the widget is no longer visible after route transition.
  final VoidCallback? onForegroundLost;

  @override
  State<FocusOnIt> createState() => _FocusOnItState();
}

class _FocusOnItState extends State<FocusOnIt> with WidgetsBindingObserver {
  final _focusKey = GlobalKey();
  bool _visible = false;
  bool _foreground = true;

  /// Provide support to Flutter 2 and above.
  T? _ambiguous<T>(T? value) => value;

  @override
  void initState() {
    super.initState();
    _ambiguous(WidgetsBinding.instance)?.addObserver(this);
  }

  @override
  void dispose() {
    _ambiguous(WidgetsBinding.instance)?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foregroundManager(state);
  }

  /// Manages the foreground state.
  void _foregroundManager(AppLifecycleState state) {
    if (!_visible) return;

    if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      _onFocus();
      _onForegroundGained();
    } else if (state == AppLifecycleState.paused && _foreground) {
      _foreground = false;
      _onUnfocus();
      _onForegroundLost();
    }
  }

  /// Manages the visibility state.
  void _visibilityManager(double visibility) {
    if (!_foreground) return;

    if (!_visible && visibility == 1) {
      _visible = true;
      _onFocus();
      _onVisibilityGained();
    } else if (_visible && visibility == 0) {
      _visible = false;
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

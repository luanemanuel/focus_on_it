library focus_on_it;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

  /// On FOCUS
  final VoidCallback? onFocus;

  final VoidCallback? onUnfocus;

  final VoidCallback? onVisibilityGained;

  final VoidCallback? onVisibilityLost;

  final VoidCallback? onForegroundGained;

  final VoidCallback? onForegroundLost;

  @override
  State<FocusOnIt> createState() => _FocusOnItState();
}

class _FocusOnItState extends State<FocusOnIt> with WidgetsBindingObserver {
  final _focusKey = GlobalKey();
  bool _visible = false;
  bool _foreground = true;

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

  void _onFocus() => widget.onFocus?.call();

  void _onUnfocus() => widget.onUnfocus?.call();

  void _onVisibilityGained() => widget.onVisibilityGained?.call();

  void _onVisibilityLost() => widget.onVisibilityLost?.call();

  void _onForegroundGained() => widget.onForegroundGained?.call();

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

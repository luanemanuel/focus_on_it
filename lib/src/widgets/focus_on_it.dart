import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/controller/focus_on_it_controller.dart';
import 'package:focus_on_it/src/engine/app_lifecycle_tracker.dart';
import 'package:focus_on_it/src/engine/focus_state_machine.dart';
import 'package:focus_on_it/src/engine/viewport_visibility_tracker.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';
import 'package:focus_on_it/src/models/focus_state.dart';
import 'package:focus_on_it/src/models/focus_viewport_config.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';
import 'package:focus_on_it/src/widgets/focus_on_it_scope.dart';

/// A widget that notifies when its subtree gains or loses focus, route
/// visibility, viewport visibility, or application foreground state.
class FocusOnIt extends StatefulWidget {
  /// Creates a [FocusOnIt] widget.
  const FocusOnIt({
    required this.child,
    this.controller,
    this.includeDialogs = true,
    this.triggerOnInit = true,
    this.notifyOnDispose = false,
    this.onFocus,
    this.onUnfocus,
    this.onVisibilityGained,
    this.onVisibilityLost,
    this.onForegroundGained,
    this.onForegroundLost,
    this.viewport,
    this.appLifecycle,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// Optional controller exposing reactive [FocusState] updates.
  final FocusOnItController? controller;

  /// Whether covering routes such as dialogs or bottom sheets unfocus this
  /// widget. Defaults to `true`.
  final bool includeDialogs;

  /// Whether [onFocus] and [onVisibilityGained] should fire when the widget
  /// first mounts in a focused state. Defaults to `true`.
  final bool triggerOnInit;

  /// Whether [onUnfocus] and [onVisibilityLost] should fire if the widget is
  /// disposed while focused. Defaults to `false`.
  final bool notifyOnDispose;

  /// Called whenever the widget transitions from unfocused to focused.
  final VoidCallback? onFocus;

  /// Called whenever the widget transitions from focused to unfocused.
  final VoidCallback? onUnfocus;

  /// Called when the widget becomes visible while the app is in foreground.
  final VoidCallback? onVisibilityGained;

  /// Called when the widget loses visibility while the app is in foreground.
  final VoidCallback? onVisibilityLost;

  /// Called when the app returns to the foreground while this widget is
  /// visible.
  final VoidCallback? onForegroundGained;

  /// Called when the app moves to the background while this widget is visible.
  final VoidCallback? onForegroundLost;

  /// Opt-in configuration for scroll and viewport intersection tracking.
  final FocusViewportConfig? viewport;

  /// Granular application lifecycle callbacks forwarded to
  /// `AppLifecycleListener`.
  final FocusAppLifecycleCallbacks? appLifecycle;

  /// Returns the enclosing [FocusState] and subscribes to all state changes.
  static FocusState of(BuildContext context) => FocusOnItScope.of(context);

  /// Returns the enclosing [FocusState], or `null` if no [FocusOnIt] exists.
  static FocusState? maybeOf(BuildContext context) =>
      FocusOnItScope.maybeOf(context);

  /// Returns whether the enclosing [FocusOnIt] is focused and rebuilds only
  /// when `isFocused` changes.
  static bool isFocusedOf(BuildContext context) =>
      FocusOnItScope.isFocusedOf(context);

  /// Returns whether the enclosing [FocusOnIt] is focused, or `null` if none.
  static bool? maybeIsFocusedOf(BuildContext context) =>
      FocusOnItScope.maybeIsFocusedOf(context);

  @override
  State<FocusOnIt> createState() => _FocusOnItState();
}

class _FocusOnItState extends State<FocusOnIt> {
  late final AppLifecycleTracker _lifecycleTracker;
  late final FocusStateMachine _stateMachine;

  bool _tickerEnabled = true;
  bool _routeActive = true;
  bool _hasIndexedOrOffstageAncestor = false;
  bool _routeSyncScheduled = false;
  bool _suppressSetState = false;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _lifecycleTracker = AppLifecycleTracker(
      onForegroundChanged: (isInForeground) =>
          _stateMachine.updateForeground(isInForeground: isInForeground),
      callbacks: widget.appLifecycle,
    );
    _stateMachine = FocusStateMachine(
      useViewport: widget.viewport != null,
      initialForeground: _lifecycleTracker.isInForeground,
      triggerOnInit: widget.triggerOnInit,
      minFocusDuration: widget.viewport?.minFocusDuration ?? Duration.zero,
      notifyOnDispose: widget.notifyOnDispose,
      onFocus: widget.onFocus,
      onUnfocus: widget.onUnfocus,
      onVisibilityGained: widget.onVisibilityGained,
      onVisibilityLost: widget.onVisibilityLost,
      onForegroundGained: widget.onForegroundGained,
      onForegroundLost: widget.onForegroundLost,
      onStateChanged: _handleStateChanged,
    );

    final controller = widget.controller;
    if (controller != null) {
      updateFocusOnItController(controller, _stateMachine.state);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kept for compatibility with Flutter >=3.13.0 (valuesOf requires 3.35.0+).
    // ignore: deprecated_member_use
    _tickerEnabled = TickerMode.of(context);
    _routeActive = _resolveRouteActive();
    _hasIndexedOrOffstageAncestor =
        context.findAncestorWidgetOfExactType<IndexedStack>() != null ||
            context.findAncestorWidgetOfExactType<Offstage>() != null;
    _scheduleRouteSync();
  }

  @override
  void didUpdateWidget(FocusOnIt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _suppressSetState = true;
    try {
      _lifecycleTracker.updateCallbacks(widget.appLifecycle);
      _stateMachine
        ..updateCallbacks(
          onFocus: widget.onFocus,
          onUnfocus: widget.onUnfocus,
          onVisibilityGained: widget.onVisibilityGained,
          onVisibilityLost: widget.onVisibilityLost,
          onForegroundGained: widget.onForegroundGained,
          onForegroundLost: widget.onForegroundLost,
          onStateChanged: _handleStateChanged,
        )
        ..updateConfig(
          useViewport: widget.viewport != null,
          minFocusDuration: widget.viewport?.minFocusDuration ?? Duration.zero,
          notifyOnDispose: widget.notifyOnDispose,
        );

      final controller = widget.controller;
      if (controller != oldWidget.controller && controller != null) {
        updateFocusOnItController(controller, _stateMachine.state);
      }

      if (widget.includeDialogs != oldWidget.includeDialogs) {
        _routeActive = _resolveRouteActive();
        _scheduleRouteSync();
      } else if (_hasIndexedOrOffstageAncestor) {
        _scheduleRouteSync();
      }
    } finally {
      _suppressSetState = false;
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _lifecycleTracker.dispose();
    _stateMachine.dispose();
    super.dispose();
  }

  bool _resolveRouteActive() {
    final route = ModalRoute.of(context);
    if (route == null) return true;
    return widget.includeDialogs ? route.isCurrent : route.isActive;
  }

  void _scheduleRouteSync() {
    if (_routeSyncScheduled) return;
    _routeSyncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _routeSyncScheduled = false;
      if (!mounted || _disposing) return;
      final isRouteActive = _tickerEnabled &&
          _routeActive &&
          (!_hasIndexedOrOffstageAncestor || !_isHiddenByAncestor());
      _stateMachine.updateRouteActive(isRouteActive: isRouteActive);
    });
  }

  bool _isHiddenByAncestor() {
    var node = context.findRenderObject();
    while (node != null) {
      final parent = node.parent;
      if (parent is RenderOffstage && parent.offstage) {
        return true;
      }
      if (parent is RenderIndexedStack) {
        final activeIndex = parent.index;
        if (activeIndex == null) return true;
        var child = parent.firstChild;
        var childIndex = 0;
        while (child != null) {
          if (identical(child, node)) {
            if (childIndex != activeIndex) return true;
            break;
          }
          child = parent.childAfter(child);
          childIndex++;
        }
      }
      node = parent;
    }
    return false;
  }

  void _handleViewportMeasured(FocusVisibilityInfo info) {
    widget.viewport?.onVisibilityChanged?.call(info);
    final threshold = widget.viewport?.threshold ?? 0.5;
    final isVisible = info.visibleFraction >= threshold - 1e-6;
    _stateMachine.updateViewport(
      isViewportVisible: isVisible,
      visibleFraction: info.visibleFraction,
    );
  }

  void _handleStateChanged(FocusState nextState) {
    final controller = widget.controller;
    if (controller != null) {
      updateFocusOnItController(controller, nextState);
    }
    if (!_disposing && !_suppressSetState && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.viewport != null
        ? ViewportVisibilityTracker(
            onVisibilityMeasured: _handleViewportMeasured,
            child: widget.child,
          )
        : widget.child;

    return FocusOnItScope(
      state: _stateMachine.state,
      child: content,
    );
  }
}

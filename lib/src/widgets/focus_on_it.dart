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

  final List<RenderOffstage> _watchedOffstages = [];
  final List<({RenderIndexedStack stack, int childIndex})>
      _watchedIndexedStacks = [];

  bool _tickerEnabled = true;
  bool _routeActive = true;
  bool _hasIndexedOrOffstageAncestor = false;
  bool _hasScopeDependents = false;
  bool _suppressSetState = false;
  bool _disposing = false;
  bool _ancestorsCached = false;
  bool _lastHiddenByAncestor = false;
  ModalRoute<dynamic>? _modalRoute;
  RenderOffstage? _modalRouteOffstage;
  late FocusState _scopeSnapshot;

  @override
  void initState() {
    super.initState();
    _lifecycleTracker = AppLifecycleTracker(
      onForegroundChanged: _handleForegroundChanged,
      callbacks: widget.appLifecycle,
    );
    _stateMachine = FocusStateMachine(
      useViewport: widget.viewport != null,
      initialForeground: _lifecycleTracker.isInForeground,
      triggerOnInit: widget.triggerOnInit,
      minFocusDuration: widget.viewport?.minFocusDuration ?? Duration.zero,
      applyDwellOnResume: widget.viewport?.applyDwellOnResume ?? false,
      notifyOnDispose: widget.notifyOnDispose,
      onFocus: widget.onFocus,
      onUnfocus: widget.onUnfocus,
      onVisibilityGained: widget.onVisibilityGained,
      onVisibilityLost: widget.onVisibilityLost,
      onForegroundGained: widget.onForegroundGained,
      onForegroundLost: widget.onForegroundLost,
      onStateChanged: _handleStateChanged,
    );
    _scopeSnapshot = _stateMachine.state;

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
    _modalRoute = ModalRoute.of(context);
    _routeActive = _resolveRouteActive();
    final hadHiddenAncestor = _hasIndexedOrOffstageAncestor;
    var hasHiddenAncestor = false;
    RenderOffstage? modalRouteOffstage;
    Widget? previousWidget;
    context.visitAncestorElements((element) {
      final ancestorWidget = element.widget;
      if (ancestorWidget is Offstage && previousWidget is PageStorage) {
        final renderObject = element.renderObject;
        if (renderObject is RenderOffstage) {
          modalRouteOffstage = renderObject;
        }
      } else if (ancestorWidget is IndexedStack || ancestorWidget is Offstage) {
        hasHiddenAncestor = true;
      }
      previousWidget = ancestorWidget;
      return true;
    });
    _modalRouteOffstage = modalRouteOffstage;
    _hasIndexedOrOffstageAncestor = hasHiddenAncestor;
    _ancestorsCached = false;
    _watchedOffstages.clear();
    _watchedIndexedStacks.clear();
    if (hasHiddenAncestor && !hadHiddenAncestor) {
      _lifecycleTracker.addAncestorWatcher(_checkWatchedAncestorsOnFrame);
    } else if (!hasHiddenAncestor && hadHiddenAncestor) {
      _lifecycleTracker.removeAncestorWatcher(_checkWatchedAncestorsOnFrame);
    }
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
          applyDwellOnResume: widget.viewport?.applyDwellOnResume ?? false,
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
    _watchedOffstages.clear();
    _watchedIndexedStacks.clear();
    _ancestorsCached = false;
    _modalRoute = null;
    _modalRouteOffstage = null;
    _lifecycleTracker
      ..removeAncestorWatcher(_checkWatchedAncestorsOnFrame)
      ..cancelRouteSync(_flushRouteSync)
      ..dispose();
    _stateMachine.dispose();
    super.dispose();
  }

  void _handleForegroundChanged(bool isInForeground) =>
      _stateMachine.updateForeground(isInForeground: isInForeground);

  bool _resolveRouteActive() {
    final route = _modalRoute;
    if (route == null) return true;
    return widget.includeDialogs ? route.isCurrent : route.isActive;
  }

  void _scheduleRouteSync() {
    if (_disposing) return;
    _lifecycleTracker.scheduleRouteSync(_flushRouteSync);
  }

  void _checkWatchedAncestorsOnFrame() {
    if (!mounted || _disposing) return;
    if (!_ancestorsCached) {
      _scheduleRouteSync();
      return;
    }
    var hidden = false;
    for (var i = 0; i < _watchedOffstages.length; i++) {
      final offstage = _watchedOffstages[i];
      if (!offstage.attached) {
        _ancestorsCached = false;
        _scheduleRouteSync();
        return;
      }
      if (offstage.offstage) {
        hidden = true;
        break;
      }
    }
    if (!hidden) {
      for (var i = 0; i < _watchedIndexedStacks.length; i++) {
        final entry = _watchedIndexedStacks[i];
        if (!entry.stack.attached) {
          _ancestorsCached = false;
          _scheduleRouteSync();
          return;
        }
        final activeIndex = entry.stack.index;
        if (activeIndex == null || activeIndex != entry.childIndex) {
          hidden = true;
          break;
        }
      }
    }
    if (hidden != _lastHiddenByAncestor) {
      _scheduleRouteSync();
    }
  }

  void _flushRouteSync() {
    if (!mounted || _disposing) return;
    final hidden = _hasIndexedOrOffstageAncestor && _isHiddenByAncestor();
    _lastHiddenByAncestor = hidden;
    final isRouteActive = _tickerEnabled && _routeActive && !hidden;
    _stateMachine.updateRouteActive(isRouteActive: isRouteActive);
  }

  bool _isHiddenByAncestor() {
    if (_ancestorsCached) {
      var cacheValid = true;
      var hidden = false;
      for (var i = 0; i < _watchedOffstages.length; i++) {
        final offstage = _watchedOffstages[i];
        if (!offstage.attached) {
          cacheValid = false;
          break;
        }
        if (offstage.offstage) hidden = true;
      }
      if (cacheValid) {
        for (var i = 0; i < _watchedIndexedStacks.length; i++) {
          final entry = _watchedIndexedStacks[i];
          if (!entry.stack.attached) {
            cacheValid = false;
            break;
          }
          final activeIndex = entry.stack.index;
          if (activeIndex == null || activeIndex != entry.childIndex) {
            hidden = true;
          }
        }
      }
      if (cacheValid) return hidden;
    }

    _watchedOffstages.clear();
    _watchedIndexedStacks.clear();
    var isHidden = false;
    var node = context.findRenderObject();
    while (node != null) {
      final parent = node.parent;
      if (parent is RenderOffstage) {
        final route = _modalRoute;
        final isModalOffstage = identical(parent, _modalRouteOffstage) ||
            (_modalRouteOffstage == null &&
                route != null &&
                route.isCurrent &&
                route.offstage);
        if (!isModalOffstage) {
          _watchedOffstages.add(parent);
          if (parent.offstage) {
            isHidden = true;
          }
        }
      }
      if (parent is RenderIndexedStack) {
        var child = parent.firstChild;
        var childIndex = 0;
        while (child != null) {
          if (identical(child, node)) {
            _watchedIndexedStacks.add((stack: parent, childIndex: childIndex));
            final activeIndex = parent.index;
            if (activeIndex == null || childIndex != activeIndex) {
              isHidden = true;
            }
            break;
          }
          child = parent.childAfter(child);
          childIndex++;
        }
      }
      node = parent;
    }
    _ancestorsCached = true;
    return isHidden;
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

  FocusState _readCurrentState() => _stateMachine.state;

  void _handleScopeDependentAdded() {
    if (_hasScopeDependents) return;
    _hasScopeDependents = true;
    if (_scopeSnapshot != _stateMachine.state && !_disposing && mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposing && _scopeSnapshot != _stateMachine.state) {
          setState(() {});
        }
      });
    }
  }

  void _handleStateChanged(FocusState nextState) {
    final controller = widget.controller;
    if (controller != null) {
      updateFocusOnItController(controller, nextState);
    }
    if (_hasScopeDependents && !_disposing && !_suppressSetState && mounted) {
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

    _scopeSnapshot = _stateMachine.state;
    return FocusOnItScope(
      state: _scopeSnapshot,
      stateReader: _readCurrentState,
      onDependentAdded: _handleScopeDependentAdded,
      child: content,
    );
  }
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/controller/focus_on_it_controller.dart';
import 'package:focus_on_it/src/engine/focus_state_machine.dart';
import 'package:focus_on_it/src/engine/shared_lifecycle_hub.dart';
import 'package:focus_on_it/src/engine/viewport_visibility_tracker.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';
import 'package:focus_on_it/src/models/focus_state.dart';
import 'package:focus_on_it/src/models/focus_viewport_config.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';

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
  static FocusState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw FlutterError(
        'FocusOnIt.of() called with a context that does not contain a '
        'FocusOnIt ancestor.',
      );
    }
    return state;
  }

  /// Returns the enclosing [FocusState], or `null` if no [FocusOnIt] exists.
  static FocusState? maybeOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_FocusOnItState>();
    if (state == null) return null;
    state._registerDependent(context, _FocusOnItState._aspectState);
    return state._currentState;
  }

  /// Returns whether the enclosing [FocusOnIt] is focused and rebuilds only
  /// when `isFocused` changes.
  static bool isFocusedOf(BuildContext context) {
    final focused = maybeIsFocusedOf(context);
    if (focused == null) {
      throw FlutterError(
        'FocusOnIt.isFocusedOf() called with a context that does not contain '
        'a FocusOnIt ancestor.',
      );
    }
    return focused;
  }

  /// Returns whether the enclosing [FocusOnIt] is focused, or `null` if none.
  static bool? maybeIsFocusedOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_FocusOnItState>();
    if (state == null) return null;
    state._registerDependent(context, _FocusOnItState._aspectFocused);
    return state._currentState.isFocused;
  }

  @override
  State<FocusOnIt> createState() => _FocusOnItState();
}

class _FocusOnItState extends State<FocusOnIt>
    implements SharedLifecycleClient {
  static const int _aspectFocused = 1 << 0;
  static const int _aspectState = 1 << 1;

  late final SharedLifecycleHub _hub;
  late final FocusStateMachine _stateMachine;

  List<RenderOffstage>? _watchedOffstages;
  List<({RenderIndexedStack stack, RenderObject child})>? _watchedIndexedStacks;
  Map<Element, int>? _dependents;
  AppLifecycleListener? _exitListener;

  bool _tickerEnabled = true;
  bool _routeActive = true;
  bool _hasIndexedOrOffstageAncestor = false;
  bool _disposing = false;
  bool _ancestorsCached = false;
  bool _pendingConfigSync = false;
  bool _routeSyncScheduled = false;
  ModalRoute<dynamic>? _modalRoute;
  RenderOffstage? _modalRouteOffstage;
  FocusVisibilityInfo? _lastVisibilityInfo;
  late FocusState _lastNotifiedState;

  FocusState get _currentState => _stateMachine.state;

  @override
  FocusAppLifecycleCallbacks? get lifecycleCallbacks => widget.appLifecycle;

  @override
  void initState() {
    super.initState();
    _hub = SharedLifecycleHub(WidgetsBinding.instance)..subscribeClient(this);
    _syncExitListener();
    _stateMachine = FocusStateMachine(
      useViewport: widget.viewport != null,
      initialForeground: _hub.isInForeground,
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
    _lastNotifiedState = _stateMachine.state;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kept for compatibility with Flutter >=3.13.0 (valuesOf requires 3.35.0+).
    // ignore: deprecated_member_use
    _tickerEnabled = TickerMode.of(context);
    _modalRoute = ModalRoute.of(context);
    _routeActive = _resolveRouteActive();
    _refreshAncestorDependencies();
    _scheduleRouteSync();
  }

  @override
  void deactivate() {
    _routeSyncScheduled = false;
    _ancestorsCached = false;
    _hasIndexedOrOffstageAncestor = false;
    _clearAncestorWatches();
    _modalRoute = null;
    _modalRouteOffstage = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _refreshAncestorDependencies();
    _scheduleRouteSync();
  }

  @override
  void didUpdateWidget(FocusOnIt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appLifecycle?.onExitRequested !=
        oldWidget.appLifecycle?.onExitRequested) {
      _syncExitListener();
    }
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
      ..updateConfig(notifyOnDispose: widget.notifyOnDispose);

    if (widget.viewport == null) {
      _lastVisibilityInfo = null;
    }

    final configChanged =
        (widget.viewport != null) != (oldWidget.viewport != null) ||
            widget.viewport?.threshold != oldWidget.viewport?.threshold ||
            widget.viewport?.minFocusDuration !=
                oldWidget.viewport?.minFocusDuration ||
            widget.viewport?.applyDwellOnResume !=
                oldWidget.viewport?.applyDwellOnResume ||
            widget.controller != oldWidget.controller ||
            widget.includeDialogs != oldWidget.includeDialogs;

    if (configChanged || _hasIndexedOrOffstageAncestor) {
      _pendingConfigSync = _pendingConfigSync || configChanged;
      _scheduleRouteSync();
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _routeSyncScheduled = false;
    _clearAncestorWatches();
    _dependents = null;
    _modalRoute = null;
    _modalRouteOffstage = null;
    _exitListener?.dispose();
    _exitListener = null;
    _hub.unsubscribeClient(this);
    _stateMachine.dispose();
    super.dispose();
  }

  @override
  void onForegroundChanged(bool isInForeground) =>
      _stateMachine.updateForeground(isInForeground: isInForeground);

  @override
  void onAncestorVisibilityChanged() {
    if (!mounted || _disposing) return;
    _ancestorsCached = false;
    _scheduleRouteSync();
  }

  @override
  void onRouteSyncFlush() {
    _routeSyncScheduled = false;
    if (!mounted || _disposing) return;
    _syncPendingConfig();
    if (!mounted || _disposing) return;

    _routeActive = _resolveRouteActive();
    final info = _lastVisibilityInfo;
    if (widget.viewport != null && info != null) {
      _applyViewportVisibility(info);
      if (!mounted || _disposing) return;
    }

    final hidden = _hasIndexedOrOffstageAncestor && _isHiddenByAncestor();
    final isRouteActive = _tickerEnabled && _routeActive && !hidden;
    _stateMachine.updateRouteActive(isRouteActive: isRouteActive);
    if (!mounted || _disposing) return;

    final controller = widget.controller;
    if (controller != null) {
      updateFocusOnItController(controller, _stateMachine.state);
    }
  }

  void _syncExitListener() {
    final wantsExitHandler = widget.appLifecycle?.onExitRequested != null;
    if (wantsExitHandler && _exitListener == null) {
      _exitListener = AppLifecycleListener(
        binding: WidgetsBinding.instance,
        onExitRequested: () => widget.appLifecycle!.onExitRequested!(),
      );
    } else if (!wantsExitHandler && _exitListener != null) {
      _exitListener?.dispose();
      _exitListener = null;
    }
  }

  bool _resolveRouteActive() {
    final route = _modalRoute;
    if (route == null) return true;
    return widget.includeDialogs ? route.isCurrent : route.isActive;
  }

  void _scheduleRouteSync() {
    if (_disposing || _routeSyncScheduled) return;
    _routeSyncScheduled = true;
    _hub.scheduleClientRouteSync(this);
  }

  void _refreshAncestorDependencies() {
    final scan = _hub.scanAncestors(context as Element);
    _modalRouteOffstage = scan.modalRouteOffstage;
    _hasIndexedOrOffstageAncestor = scan.hasHiddenAncestor;
    _ancestorsCached = false;
    _clearAncestorWatches();
  }

  void _clearAncestorWatches() {
    final offstages = _watchedOffstages;
    if (offstages != null && offstages.isNotEmpty) {
      for (var i = 0; i < offstages.length; i++) {
        _hub.unwatchOffstage(offstages[i], this);
      }
      offstages.clear();
    }
    final stacks = _watchedIndexedStacks;
    if (stacks != null && stacks.isNotEmpty) {
      for (var i = 0; i < stacks.length; i++) {
        _hub.unwatchIndexedStack(stacks[i].stack, this);
      }
      stacks.clear();
    }
  }

  void _syncPendingConfig() {
    if (!_pendingConfigSync) return;
    _pendingConfigSync = false;
    _stateMachine.updateConfig(
      useViewport: widget.viewport != null,
      minFocusDuration: widget.viewport?.minFocusDuration ?? Duration.zero,
      applyDwellOnResume: widget.viewport?.applyDwellOnResume ?? false,
    );
  }

  bool _isHiddenByAncestor() {
    final offstages = _watchedOffstages;
    final stacks = _watchedIndexedStacks;
    if (_ancestorsCached) {
      var cacheValid = true;
      var hidden = false;
      if (offstages != null) {
        for (var i = 0; i < offstages.length; i++) {
          final offstage = offstages[i];
          if (!offstage.attached) {
            cacheValid = false;
            break;
          }
          if (offstage.offstage) hidden = true;
        }
      }
      if (cacheValid && stacks != null) {
        for (var i = 0; i < stacks.length; i++) {
          final entry = stacks[i];
          if (!entry.stack.attached || !entry.child.attached) {
            cacheValid = false;
            break;
          }
          if (_isIndexedStackChildHidden(entry.stack, entry.child)) {
            hidden = true;
          }
        }
      }
      if (cacheValid) return hidden;
    }

    _clearAncestorWatches();
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
          (_watchedOffstages ??= []).add(parent);
          _hub.watchOffstage(parent, this);
          if (parent.offstage) {
            isHidden = true;
          }
        }
      }
      if (parent is RenderIndexedStack) {
        (_watchedIndexedStacks ??= []).add((stack: parent, child: node));
        _hub.watchIndexedStack(parent, this);
        if (_isIndexedStackChildHidden(parent, node)) {
          isHidden = true;
        }
      }
      node = parent;
    }
    _ancestorsCached = true;
    return isHidden;
  }

  static bool _isIndexedStackChildHidden(
    RenderIndexedStack stack,
    RenderObject targetChild,
  ) {
    final activeIndex = stack.index;
    if (activeIndex == null) return true;
    var child = stack.firstChild;
    var index = 0;
    while (child != null) {
      if (index == activeIndex) {
        return !identical(child, targetChild);
      }
      child = stack.childAfter(child);
      index++;
    }
    return true;
  }

  void _handleViewportMeasured(FocusVisibilityInfo info) {
    if (!mounted || _disposing || widget.viewport == null) return;
    _syncPendingConfig();
    if (!mounted || _disposing || widget.viewport == null) return;
    _lastVisibilityInfo = info;
    _applyViewportVisibility(info);
    if (!mounted || _disposing) return;
    widget.viewport?.onVisibilityChanged?.call(info);
  }

  void _applyViewportVisibility(FocusVisibilityInfo info) {
    final threshold = widget.viewport?.threshold ?? 0.5;
    final isVisible = info.visibleFraction >= threshold - 1e-6;
    _stateMachine.updateViewport(
      isViewportVisible: isVisible,
      visibleFraction: info.visibleFraction,
    );
  }

  void _registerDependent(BuildContext dependentContext, int aspect) {
    if (dependentContext is Element && dependentContext.mounted) {
      final dependents = _dependents ??= {};
      dependents[dependentContext] =
          (dependents[dependentContext] ?? 0) | aspect;
    }
  }

  void _handleStateChanged(FocusState nextState) {
    final previous = _lastNotifiedState;
    _lastNotifiedState = nextState;

    final controller = widget.controller;
    if (controller != null) {
      updateFocusOnItController(controller, nextState);
    }

    final dependents = _dependents;
    if (dependents == null || dependents.isEmpty || _disposing || !mounted) {
      return;
    }

    final focusedChanged = previous.isFocused != nextState.isFocused;
    dependents.removeWhere((element, aspect) {
      if (!element.mounted) return true;
      if ((aspect & _aspectState) != 0 ||
          (focusedChanged && (aspect & _aspectFocused) != 0)) {
        element.markNeedsBuild();
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewport == null) {
      return widget.child;
    }
    return ViewportVisibilityTracker(
      onVisibilityMeasured: _handleViewportMeasured,
      child: widget.child,
    );
  }
}

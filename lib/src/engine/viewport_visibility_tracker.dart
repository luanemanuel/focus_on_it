import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';

/// Tracks viewport intersection bounds for [child] without polling timers.
class ViewportVisibilityTracker extends StatefulWidget {
  /// Creates a [ViewportVisibilityTracker].
  const ViewportVisibilityTracker({
    required this.onVisibilityMeasured,
    required this.child,
    super.key,
  });

  /// Called when measured visibility bounds or visible fraction change.
  final ValueChanged<FocusVisibilityInfo> onVisibilityMeasured;

  /// The widget whose viewport intersection is tracked.
  final Widget child;

  @override
  State<ViewportVisibilityTracker> createState() =>
      _ViewportVisibilityTrackerState();
}

class _ViewportVisibilityTrackerState extends State<ViewportVisibilityTracker>
    with WidgetsBindingObserver {
  final List<ScrollableState> _scrollables = [];
  final List<ScrollPosition> _scrollPositions = [];

  RenderBox? _renderBox;
  FocusVisibilityInfo? _lastInfo;
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollListeners();
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(ViewportVisibilityTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() {
    _scheduleMeasurement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachScrollListeners();
    _renderBox = null;
    super.dispose();
  }

  void _attachScrollListeners() {
    _detachScrollListeners();
    Scrollable.maybeOf(context);

    var currentContext = context;
    while (true) {
      final scrollable =
          currentContext.findAncestorStateOfType<ScrollableState>();
      if (scrollable == null) break;
      _scrollables.add(scrollable);
      final position = scrollable.position..addListener(_scheduleMeasurement);
      _scrollPositions.add(position);
      currentContext = scrollable.context;
    }
  }

  void _detachScrollListeners() {
    for (final position in _scrollPositions) {
      position.removeListener(_scheduleMeasurement);
    }
    _scrollPositions.clear();
    _scrollables.clear();
  }

  void _handleRenderBoxAttached(RenderBox renderBox) {
    _renderBox = renderBox;
    _scheduleMeasurement();
  }

  void _handleRenderBoxDetached(RenderBox renderBox) {
    if (identical(_renderBox, renderBox)) {
      _renderBox = null;
    }
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled || !mounted) return;
    _measurementScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      _measureVisibility();
    });
  }

  void _measureVisibility() {
    final renderBox = _renderBox;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      return;
    }

    final size = renderBox.size;
    if (size.isEmpty) {
      _emitIfChanged(
        FocusVisibilityInfo(
          visibleFraction: 0,
          size: size,
          visibleBounds: Rect.zero,
        ),
      );
      return;
    }

    final widgetRect = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero),
      renderBox.localToGlobal(size.bottomRight(Offset.zero)),
    );

    var clipRect = _resolveWindowBounds() ?? widgetRect;
    for (final scrollable in _scrollables) {
      if (!scrollable.mounted) continue;
      final vpRender = scrollable.context.findRenderObject();
      if (vpRender is RenderBox && vpRender.attached && vpRender.hasSize) {
        final vpRect = Rect.fromPoints(
          vpRender.localToGlobal(Offset.zero),
          vpRender.localToGlobal(vpRender.size.bottomRight(Offset.zero)),
        );
        clipRect = clipRect.intersect(vpRect);
      }
    }

    final intersection = widgetRect.intersect(clipRect);
    if (intersection.isEmpty ||
        intersection.width <= 0 ||
        intersection.height <= 0) {
      _emitIfChanged(
        FocusVisibilityInfo(
          visibleFraction: 0,
          size: size,
          visibleBounds: Rect.zero,
        ),
      );
      return;
    }

    final totalArea = widgetRect.width * widgetRect.height;
    final visibleArea = intersection.width * intersection.height;
    final fraction =
        (totalArea > 0 ? visibleArea / totalArea : 0.0).clamp(0.0, 1.0);
    final localBounds = intersection.shift(-widgetRect.topLeft);

    _emitIfChanged(
      FocusVisibilityInfo(
        visibleFraction: fraction,
        size: size,
        visibleBounds: localBounds,
      ),
    );
  }

  Rect? _resolveWindowBounds() {
    final view = View.maybeOf(context);
    if (view != null) {
      return Offset.zero & (view.physicalSize / view.devicePixelRatio);
    }
    final mediaSize = MediaQuery.maybeSizeOf(context);
    if (mediaSize != null) {
      return Offset.zero & mediaSize;
    }
    return null;
  }

  void _emitIfChanged(FocusVisibilityInfo info) {
    if (info == _lastInfo) return;
    _lastInfo = info;
    widget.onVisibilityMeasured(info);
  }

  @override
  Widget build(BuildContext context) {
    return _ViewportRenderObjectWidget(
      onLayoutPerformed: _scheduleMeasurement,
      onRenderBoxAttached: _handleRenderBoxAttached,
      onRenderBoxDetached: _handleRenderBoxDetached,
      child: widget.child,
    );
  }
}

class _ViewportRenderObjectWidget extends SingleChildRenderObjectWidget {
  const _ViewportRenderObjectWidget({
    required this.onLayoutPerformed,
    required this.onRenderBoxAttached,
    required this.onRenderBoxDetached,
    required super.child,
  });

  final VoidCallback onLayoutPerformed;
  final ValueChanged<RenderBox> onRenderBoxAttached;
  final ValueChanged<RenderBox> onRenderBoxDetached;

  @override
  _RenderViewportVisibility createRenderObject(BuildContext context) {
    return _RenderViewportVisibility(
      onLayoutPerformed: onLayoutPerformed,
      onRenderBoxAttached: onRenderBoxAttached,
      onRenderBoxDetached: onRenderBoxDetached,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderViewportVisibility renderObject,
  ) {
    renderObject
      ..onLayoutPerformed = onLayoutPerformed
      ..onRenderBoxAttached = onRenderBoxAttached
      ..onRenderBoxDetached = onRenderBoxDetached;
  }
}

class _RenderViewportVisibility extends RenderProxyBox {
  _RenderViewportVisibility({
    required this.onLayoutPerformed,
    required this.onRenderBoxAttached,
    required this.onRenderBoxDetached,
  });

  VoidCallback onLayoutPerformed;
  ValueChanged<RenderBox> onRenderBoxAttached;
  ValueChanged<RenderBox> onRenderBoxDetached;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    onRenderBoxAttached(this);
  }

  @override
  void detach() {
    onRenderBoxDetached(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    onLayoutPerformed();
  }
}

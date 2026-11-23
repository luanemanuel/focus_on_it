import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/engine/viewport_visibility_hub.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';

/// Tracks viewport intersection bounds for [child] without polling timers.
class ViewportVisibilityTracker extends SingleChildRenderObjectWidget {
  /// Creates a [ViewportVisibilityTracker].
  const ViewportVisibilityTracker({
    required this.onVisibilityMeasured,
    required super.child,
    super.key,
  });

  /// Called when measured visibility bounds or visible fraction change.
  final ValueChanged<FocusVisibilityInfo> onVisibilityMeasured;

  @override
  SingleChildRenderObjectElement createElement() =>
      _ViewportVisibilityElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderViewportVisibility(
      onLayoutPerformed:
          (context as _ViewportVisibilityElement).scheduleMeasurement,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderViewportVisibility).onLayoutPerformed =
        (context as _ViewportVisibilityElement).scheduleMeasurement;
  }
}

class _ViewportVisibilityElement extends SingleChildRenderObjectElement {
  _ViewportVisibilityElement(super.widget);

  final List<ScrollableState> _scrollables = [];
  final List<ScrollPosition> _scrollPositions = [];
  FlutterView? _view;
  FocusVisibilityInfo? _lastInfo;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _view = View.maybeOf(this);
    ViewportVisibilityHub().addMetricsListener(scheduleMeasurement);
    _attachScrollListeners();
    scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(this);
    _attachScrollListeners();
    scheduleMeasurement();
  }

  @override
  void update(covariant SingleChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    scheduleMeasurement();
  }

  @override
  void unmount() {
    ViewportVisibilityHub()
      ..removeMetricsListener(scheduleMeasurement)
      ..cancelFlush(_measureVisibilityWithCache);
    _detachScrollListeners();
    _view = null;
    super.unmount();
  }

  void _attachScrollListeners() {
    _detachScrollListeners();
    var scrollable = Scrollable.maybeOf(this);
    while (scrollable != null) {
      _scrollables.add(scrollable);
      final position = scrollable.position..addListener(scheduleMeasurement);
      _scrollPositions.add(position);
      scrollable =
          scrollable.context.findAncestorStateOfType<ScrollableState>();
    }
  }

  void _detachScrollListeners() {
    for (final position in _scrollPositions) {
      position.removeListener(scheduleMeasurement);
    }
    _scrollPositions.clear();
    _scrollables.clear();
  }

  void scheduleMeasurement() {
    if (!mounted) return;
    ViewportVisibilityHub().scheduleFlush(_measureVisibilityWithCache);
  }

  void _measureVisibilityWithCache(
    Map<ScrollableState, Rect> scrollableRectCache,
    Map<FlutterView, Rect> windowBoundsCache,
  ) {
    if (!mounted) return;
    final box = renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final size = box.size;
    if (size.isEmpty) {
      _emitZeroIfChanged(size);
      return;
    }

    final widgetRect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & size,
    );

    var clipRect = _resolveWindowBounds(windowBoundsCache) ?? widgetRect;
    for (final scrollable in _scrollables) {
      if (!scrollable.mounted) continue;
      var vpRect = scrollableRectCache[scrollable];
      if (vpRect == null) {
        final vpRender = scrollable.context.findRenderObject();
        if (vpRender is RenderBox && vpRender.attached && vpRender.hasSize) {
          vpRect = MatrixUtils.transformRect(
            vpRender.getTransformTo(null),
            Offset.zero & vpRender.size,
          );
          scrollableRectCache[scrollable] = vpRect;
        }
      }
      if (vpRect != null) {
        clipRect = clipRect.intersect(vpRect);
      }
    }

    final intersection = widgetRect.intersect(clipRect);
    if (intersection.isEmpty ||
        intersection.width <= 0 ||
        intersection.height <= 0) {
      _emitZeroIfChanged(size);
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

  Rect? _resolveWindowBounds(Map<FlutterView, Rect> windowBoundsCache) {
    final view = _view;
    if (view != null) {
      return windowBoundsCache[view] ??=
          Offset.zero & (view.physicalSize / view.devicePixelRatio);
    }
    final mediaQuery =
        getElementForInheritedWidgetOfExactType<MediaQuery>()?.widget;
    if (mediaQuery is MediaQuery) {
      return Offset.zero & mediaQuery.data.size;
    }
    return null;
  }

  void _emitZeroIfChanged(Size size) {
    final last = _lastInfo;
    if (last != null &&
        last.visibleFraction == 0 &&
        last.size == size &&
        last.visibleBounds == Rect.zero) {
      return;
    }
    _emitIfChanged(
      FocusVisibilityInfo(
        visibleFraction: 0,
        size: size,
        visibleBounds: Rect.zero,
      ),
    );
  }

  void _emitIfChanged(FocusVisibilityInfo info) {
    if (info == _lastInfo) return;
    _lastInfo = info;
    (widget as ViewportVisibilityTracker).onVisibilityMeasured(info);
  }
}

class _RenderViewportVisibility extends RenderProxyBox {
  _RenderViewportVisibility({
    required this.onLayoutPerformed,
  });

  VoidCallback onLayoutPerformed;

  @override
  void performLayout() {
    super.performLayout();
    onLayoutPerformed();
  }
}

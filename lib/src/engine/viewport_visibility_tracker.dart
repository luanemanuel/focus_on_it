import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/engine/viewport_geometry.dart';
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
      onNeedsMeasurement:
          (context as _ViewportVisibilityElement).scheduleMeasurement,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderViewportVisibility).onNeedsMeasurement =
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
  void deactivate() {
    ViewportVisibilityHub()
      ..removeMetricsListener(scheduleMeasurement)
      ..cancelFlush(_measureVisibilityWithCache);
    _detachScrollListeners();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    ViewportVisibilityHub().addMetricsListener(scheduleMeasurement);
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
    Map<RenderObject, Matrix4> ancestorTransformCache,
  ) {
    if (!mounted) return;
    final box = renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final size = box.size;
    if (size.isEmpty || !size.isFinite) {
      _emitZeroIfChanged(size.isFinite ? size : Size.zero);
      return;
    }

    final transform = box.getTransformTo(null);
    final isAxisAligned = isAxisAlignedTransform(transform);
    final axisRect = isAxisAligned
        ? MatrixUtils.transformRect(transform, Offset.zero & size)
        : null;
    if (axisRect != null && !axisRect.isFinite) {
      _emitZeroIfChanged(size);
      return;
    }

    var clipRect = _resolveWindowBounds(windowBoundsCache) ??
        axisRect ??
        MatrixUtils.transformRect(transform, Offset.zero & size);
    if (!clipRect.isFinite || clipRect.isEmpty) {
      _emitZeroIfChanged(size);
      return;
    }

    for (final scrollable in _scrollables) {
      if (!scrollable.mounted) continue;
      var vpRect = scrollableRectCache[scrollable];
      if (vpRect == null) {
        final vpRender = scrollable.context.findRenderObject();
        if (vpRender is RenderBox && vpRender.attached && vpRender.hasSize) {
          final resolved = MatrixUtils.transformRect(
            vpRender.getTransformTo(null),
            Offset.zero & vpRender.size,
          );
          if (resolved.isFinite) {
            vpRect = resolved;
            scrollableRectCache[scrollable] = resolved;
          }
        }
      }
      if (vpRect != null) {
        clipRect = clipRect.intersect(vpRect);
        if (clipRect.isEmpty || clipRect.width <= 0 || clipRect.height <= 0) {
          _emitZeroIfChanged(size);
          return;
        }
      }
    }

    RenderObject node = box;
    var parent = node.parent;
    while (parent != null) {
      final localClip = parent.describeApproximatePaintClip(node);
      if (localClip != null) {
        if (localClip.isEmpty) {
          _emitZeroIfChanged(size);
          return;
        }
        if (localClip.isFinite) {
          final parentTransform =
              ancestorTransformCache[parent] ??= parent.getTransformTo(null);
          final globalClip =
              MatrixUtils.transformRect(parentTransform, localClip);
          if (globalClip.isFinite) {
            clipRect = clipRect.intersect(globalClip);
            if (clipRect.isEmpty ||
                clipRect.width <= 0 ||
                clipRect.height <= 0) {
              _emitZeroIfChanged(size);
              return;
            }
          }
        }
      }
      node = parent;
      parent = parent.parent;
    }

    if (axisRect != null) {
      final intersection = axisRect.intersect(clipRect);
      if (!intersection.isFinite ||
          intersection.isEmpty ||
          intersection.width <= 0 ||
          intersection.height <= 0) {
        _emitZeroIfChanged(size);
        return;
      }

      final totalArea = axisRect.width * axisRect.height;
      final visibleArea = intersection.width * intersection.height;
      final rawFraction = totalArea > 0 ? visibleArea / totalArea : 0.0;
      if (!rawFraction.isFinite) {
        _emitZeroIfChanged(size);
        return;
      }
      final fraction = rawFraction.clamp(0.0, 1.0);
      final localBounds = intersection.shift(-axisRect.topLeft);

      _emitIfChanged(
        FocusVisibilityInfo(
          visibleFraction: fraction,
          size: size,
          visibleBounds: localBounds,
        ),
      );
      return;
    }

    final rotated = computeRotatedVisibility(
      size: size,
      transform: transform,
      clipRect: clipRect,
    );
    if (rotated.visibleFraction <= 0) {
      _emitZeroIfChanged(size);
      return;
    }

    _emitIfChanged(
      FocusVisibilityInfo(
        visibleFraction: rotated.visibleFraction,
        size: size,
        visibleBounds: rotated.visibleBounds,
      ),
    );
  }

  Rect? _resolveWindowBounds(Map<FlutterView, Rect> windowBoundsCache) {
    final view = _view;
    if (view != null && view.devicePixelRatio > 0) {
      final logicalSize = view.physicalSize / view.devicePixelRatio;
      if (logicalSize.isFinite) {
        return windowBoundsCache[view] ??= Offset.zero & logicalSize;
      }
    }
    final mediaQuery =
        getElementForInheritedWidgetOfExactType<MediaQuery>()?.widget;
    if (mediaQuery is MediaQuery && mediaQuery.data.size.isFinite) {
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
    required this.onNeedsMeasurement,
  });

  VoidCallback onNeedsMeasurement;

  @override
  void performLayout() {
    super.performLayout();
    onNeedsMeasurement();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    onNeedsMeasurement();
    super.paint(context, offset);
  }
}

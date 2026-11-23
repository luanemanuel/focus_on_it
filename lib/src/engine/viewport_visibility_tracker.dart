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

class _ViewportVisibilityElement extends SingleChildRenderObjectElement
    implements ViewportTrackerClient {
  _ViewportVisibilityElement(super.widget);

  late final ViewportVisibilityHub _hub;
  ScrollableState? _primaryScrollable;
  ScrollPosition? _primaryScrollPosition;
  List<ScrollableState>? _extraScrollables;
  List<ScrollPosition>? _extraPositions;
  FlutterView? _view;
  FocusVisibilityInfo? _lastInfo;
  bool _measurementPending = false;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _hub = ViewportVisibilityHub()..addMetricsTracker(this);
    _view = View.maybeOf(this);
    _attachScrollListeners(subscribe: true);
    scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(this);
    _attachScrollListeners(subscribe: true);
    scheduleMeasurement();
  }

  @override
  void deactivate() {
    _measurementPending = false;
    _hub.removeMetricsTracker(this);
    _detachScrollListeners();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _hub.addMetricsTracker(this);
    _attachScrollListeners(subscribe: false);
    scheduleMeasurement();
  }

  @override
  void update(covariant SingleChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    scheduleMeasurement();
  }

  @override
  void unmount() {
    _measurementPending = false;
    _hub.removeMetricsTracker(this);
    _detachScrollListeners();
    _view = null;
    super.unmount();
  }

  void _attachScrollListeners({required bool subscribe}) {
    _detachScrollListeners();
    var scrollable =
        subscribe ? Scrollable.maybeOf(this) : _findNearestScrollable();
    while (scrollable != null) {
      final position = scrollable.position;
      _hub.attachScrollPosition(position, this);
      if (_primaryScrollable == null) {
        _primaryScrollable = scrollable;
        _primaryScrollPosition = position;
      } else {
        (_extraScrollables ??= []).add(scrollable);
        (_extraPositions ??= []).add(position);
      }
      scrollable = _hub.findOuterScrollable(scrollable);
    }
  }

  ScrollableState? _findNearestScrollable() {
    ScrollableState? found;
    visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        found = element.state as ScrollableState;
        return false;
      }
      return true;
    });
    return found;
  }

  void _detachScrollListeners() {
    final primaryPosition = _primaryScrollPosition;
    if (primaryPosition != null) {
      _hub.detachScrollPosition(primaryPosition, this);
      _primaryScrollPosition = null;
      _primaryScrollable = null;
    }
    final extraPositions = _extraPositions;
    if (extraPositions != null) {
      for (var i = 0; i < extraPositions.length; i++) {
        _hub.detachScrollPosition(extraPositions[i], this);
      }
      extraPositions.clear();
    }
    _extraScrollables?.clear();
  }

  @override
  void scheduleMeasurement() {
    if (!mounted || _measurementPending) return;
    _measurementPending = true;
    _hub.scheduleTracker(this);
  }

  @override
  void flushMeasurement(
    Map<ScrollableState, Rect> scrollableRectCache,
    Map<FlutterView, Rect> windowBoundsCache,
    Map<RenderObject, Matrix4> ancestorTransformCache,
    Map<RenderObject, Rect> ancestorClipCache,
    List<RenderObject> clipTrailScratch,
    Matrix4 scratchTransform,
  ) {
    if (!mounted || !_measurementPending) {
      _measurementPending = false;
      return;
    }
    _measurementPending = false;

    final box = renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final size = box.size;
    if (size.isEmpty || !size.isFinite) {
      _emitZeroIfChanged(size.isFinite ? size : Size.zero);
      return;
    }

    final boxParent = box.parent;
    if (boxParent != null) {
      final parentTransform =
          ancestorTransformCache[boxParent] ??= boxParent.getTransformTo(null);
      scratchTransform.setFrom(parentTransform);
      boxParent.applyPaintTransform(box, scratchTransform);
    } else {
      scratchTransform.setFrom(box.getTransformTo(null));
    }

    final isAxisAligned = isAxisAlignedTransform(scratchTransform);
    double widgetLeft = 0;
    double widgetTop = 0;
    double widgetRight = 0;
    double widgetBottom = 0;
    var hasAxisBounds = false;

    if (isAxisAligned) {
      final s = scratchTransform.storage;
      if (s[11] == 0.0 && s[15] == 1.0) {
        final x0 = s[12];
        final y0 = s[13];
        final x1 = s[0] * size.width + x0;
        final y1 = s[5] * size.height + y0;
        widgetLeft = x0 < x1 ? x0 : x1;
        widgetRight = x0 > x1 ? x0 : x1;
        widgetTop = y0 < y1 ? y0 : y1;
        widgetBottom = y0 > y1 ? y0 : y1;
        if (!widgetLeft.isFinite ||
            !widgetRight.isFinite ||
            !widgetTop.isFinite ||
            !widgetBottom.isFinite) {
          _emitZeroIfChanged(size);
          return;
        }
        hasAxisBounds = true;
      } else {
        final rect =
            MatrixUtils.transformRect(scratchTransform, Offset.zero & size);
        if (!rect.isFinite) {
          _emitZeroIfChanged(size);
          return;
        }
        widgetLeft = rect.left;
        widgetTop = rect.top;
        widgetRight = rect.right;
        widgetBottom = rect.bottom;
        hasAxisBounds = true;
      }
    }

    var clipRect = _resolveWindowBounds(windowBoundsCache) ??
        (hasAxisBounds
            ? Rect.fromLTRB(widgetLeft, widgetTop, widgetRight, widgetBottom)
            : MatrixUtils.transformRect(scratchTransform, Offset.zero & size));
    if (!clipRect.isFinite || clipRect.isEmpty) {
      _emitZeroIfChanged(size);
      return;
    }

    final primary = _primaryScrollable;
    if (primary != null) {
      clipRect = _intersectScrollable(
        clipRect,
        primary,
        scrollableRectCache,
        ancestorTransformCache,
      );
      if (clipRect.isEmpty || clipRect.width <= 0 || clipRect.height <= 0) {
        _emitZeroIfChanged(size);
        return;
      }
      final extras = _extraScrollables;
      if (extras != null) {
        for (var i = 0; i < extras.length; i++) {
          clipRect = _intersectScrollable(
            clipRect,
            extras[i],
            scrollableRectCache,
            ancestorTransformCache,
          );
          if (clipRect.isEmpty || clipRect.width <= 0 || clipRect.height <= 0) {
            _emitZeroIfChanged(size);
            return;
          }
        }
      }
    }

    if (boxParent != null) {
      final parentClip = boxParent.describeApproximatePaintClip(box);
      if (parentClip != null) {
        if (parentClip.isEmpty) {
          _emitZeroIfChanged(size);
          return;
        }
        if (parentClip.isFinite) {
          final parentTransform = ancestorTransformCache[boxParent] ??=
              boxParent.getTransformTo(null);
          final globalClip =
              MatrixUtils.transformRect(parentTransform, parentClip);
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

      final ancestorClip = _resolveAncestorClip(
        boxParent,
        ancestorClipCache,
        ancestorTransformCache,
        clipTrailScratch,
      );
      if (!identical(ancestorClip, Rect.largest)) {
        if (ancestorClip.isEmpty) {
          _emitZeroIfChanged(size);
          return;
        }
        clipRect = clipRect.intersect(ancestorClip);
        if (clipRect.isEmpty || clipRect.width <= 0 || clipRect.height <= 0) {
          _emitZeroIfChanged(size);
          return;
        }
      }
    }

    if (hasAxisBounds) {
      if (widgetRight <= clipRect.left ||
          widgetLeft >= clipRect.right ||
          widgetBottom <= clipRect.top ||
          widgetTop >= clipRect.bottom) {
        _emitZeroIfChanged(size);
        return;
      }

      final iLeft = widgetLeft > clipRect.left ? widgetLeft : clipRect.left;
      final iTop = widgetTop > clipRect.top ? widgetTop : clipRect.top;
      final iRight =
          widgetRight < clipRect.right ? widgetRight : clipRect.right;
      final iBottom =
          widgetBottom < clipRect.bottom ? widgetBottom : clipRect.bottom;

      final iWidth = iRight - iLeft;
      final iHeight = iBottom - iTop;
      if (iWidth <= 0 || iHeight <= 0) {
        _emitZeroIfChanged(size);
        return;
      }

      final totalArea = (widgetRight - widgetLeft) * (widgetBottom - widgetTop);
      final rawFraction = totalArea > 0 ? (iWidth * iHeight) / totalArea : 0.0;
      if (!rawFraction.isFinite) {
        _emitZeroIfChanged(size);
        return;
      }

      final fraction = rawFraction.clamp(0.0, 1.0);
      final bLeft = iLeft - widgetLeft;
      final bTop = iTop - widgetTop;
      final bRight = iRight - widgetLeft;
      final bBottom = iBottom - widgetTop;

      final last = _lastInfo;
      if (last != null &&
          last.visibleFraction == fraction &&
          last.size == size &&
          last.visibleBounds.left == bLeft &&
          last.visibleBounds.top == bTop &&
          last.visibleBounds.right == bRight &&
          last.visibleBounds.bottom == bBottom) {
        return;
      }

      final info = FocusVisibilityInfo(
        visibleFraction: fraction,
        size: size,
        visibleBounds: Rect.fromLTRB(bLeft, bTop, bRight, bBottom),
      );
      _lastInfo = info;
      (widget as ViewportVisibilityTracker).onVisibilityMeasured(info);
      return;
    }

    final rotated = computeRotatedVisibility(
      size: size,
      transform: scratchTransform,
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

  Rect _resolveAncestorClip(
    RenderObject start,
    Map<RenderObject, Rect> ancestorClipCache,
    Map<RenderObject, Matrix4> ancestorTransformCache,
    List<RenderObject> trail,
  ) {
    final directHit = ancestorClipCache[start];
    if (directHit != null) return directHit;

    trail.clear();
    var runningClip = Rect.largest;
    RenderObject? cursor = start;
    while (cursor != null) {
      final cached = ancestorClipCache[cursor];
      if (cached != null) {
        runningClip = cached;
        break;
      }
      trail.add(cursor);
      cursor = cursor.parent;
    }

    for (var i = trail.length - 1; i >= 0; i--) {
      final node = trail[i];
      if (runningClip.isEmpty) {
        ancestorClipCache[node] = Rect.zero;
        continue;
      }
      final parent = node.parent;
      final localClip = parent?.describeApproximatePaintClip(node);
      if (localClip != null) {
        if (localClip.isEmpty) {
          runningClip = Rect.zero;
        } else if (localClip.isFinite && parent != null) {
          final parentTransform =
              ancestorTransformCache[parent] ??= parent.getTransformTo(null);
          final globalClip =
              MatrixUtils.transformRect(parentTransform, localClip);
          if (globalClip.isFinite) {
            runningClip = identical(runningClip, Rect.largest)
                ? globalClip
                : runningClip.intersect(globalClip);
            if (runningClip.width <= 0 || runningClip.height <= 0) {
              runningClip = Rect.zero;
            }
          }
        }
      }
      ancestorClipCache[node] = runningClip;
    }
    trail.clear();
    return runningClip;
  }

  Rect _intersectScrollable(
    Rect clipRect,
    ScrollableState scrollable,
    Map<ScrollableState, Rect> scrollableRectCache,
    Map<RenderObject, Matrix4> ancestorTransformCache,
  ) {
    if (!scrollable.mounted) return clipRect;
    var vpRect = scrollableRectCache[scrollable];
    if (vpRect == null) {
      final vpRender = scrollable.context.findRenderObject();
      if (vpRender is RenderBox && vpRender.attached && vpRender.hasSize) {
        final vpTransform =
            ancestorTransformCache[vpRender] ??= vpRender.getTransformTo(null);
        final resolved =
            MatrixUtils.transformRect(vpTransform, Offset.zero & vpRender.size);
        if (resolved.isFinite) {
          vpRect = resolved;
          scrollableRectCache[scrollable] = resolved;
        }
      }
    }
    return vpRect != null ? clipRect.intersect(vpRect) : clipRect;
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

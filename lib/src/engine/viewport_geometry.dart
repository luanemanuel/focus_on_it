import 'package:flutter/rendering.dart';

/// Returns `true` when [transform] only scales, flips, or translates along
/// coordinate axes.
bool isAxisAlignedTransform(Matrix4 transform) {
  final s = transform.storage;
  return s[1] == 0.0 && s[4] == 0.0 && s[3] == 0.0 && s[7] == 0.0;
}

/// Computes exact visible fraction and local bounds for a transformed quad
/// (rotated, skewed, or perspective-projected) against [clipRect].
({double visibleFraction, Rect visibleBounds}) computeRotatedVisibility({
  required Size size,
  required Matrix4 transform,
  required Rect clipRect,
}) {
  if (size.isEmpty ||
      !size.isFinite ||
      !clipRect.isFinite ||
      clipRect.isEmpty) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  final w = size.width;
  final h = size.height;
  final c0 = MatrixUtils.transformPoint(transform, Offset.zero);
  final c1 = MatrixUtils.transformPoint(transform, Offset(w, 0));
  final c2 = MatrixUtils.transformPoint(transform, Offset(w, h));
  final c3 = MatrixUtils.transformPoint(transform, Offset(0, h));
  if (!c0.isFinite || !c1.isFinite || !c2.isFinite || !c3.isFinite) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  var minX = c0.dx;
  var maxX = c0.dx;
  var minY = c0.dy;
  var maxY = c0.dy;

  void expand(Offset point) {
    if (point.dx < minX) minX = point.dx;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dy > maxY) maxY = point.dy;
  }

  expand(c1);
  expand(c2);
  expand(c3);

  if (maxX <= clipRect.left ||
      minX >= clipRect.right ||
      maxY <= clipRect.top ||
      minY >= clipRect.bottom) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  if (minX >= clipRect.left &&
      maxX <= clipRect.right &&
      minY >= clipRect.top &&
      maxY <= clipRect.bottom) {
    return (visibleFraction: 1.0, visibleBounds: Offset.zero & size);
  }

  final quad = <Offset>[c0, c1, c2, c3];
  final totalArea = _polygonArea(quad);
  if (!totalArea.isFinite || totalArea <= 0) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  var clipped = _clipAgainstEdge(
    quad,
    clipRect.left,
    isVertical: true,
    keepGreaterOrEqual: true,
  );
  clipped = _clipAgainstEdge(
    clipped,
    clipRect.right,
    isVertical: true,
    keepGreaterOrEqual: false,
  );
  clipped = _clipAgainstEdge(
    clipped,
    clipRect.top,
    isVertical: false,
    keepGreaterOrEqual: true,
  );
  clipped = _clipAgainstEdge(
    clipped,
    clipRect.bottom,
    isVertical: false,
    keepGreaterOrEqual: false,
  );
  if (clipped.length < 3) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  final visibleArea = _polygonArea(clipped);
  if (!visibleArea.isFinite || visibleArea <= 0) {
    return (visibleFraction: 0.0, visibleBounds: Rect.zero);
  }

  final fraction = (visibleArea / totalArea).clamp(0.0, 1.0);
  final inverse = Matrix4.copy(transform);
  if (inverse.invert() == 0.0) {
    return (visibleFraction: fraction, visibleBounds: Rect.zero);
  }

  var localMinX = double.infinity;
  var localMaxX = double.negativeInfinity;
  var localMinY = double.infinity;
  var localMaxY = double.negativeInfinity;

  for (final vertex in clipped) {
    final local = MatrixUtils.transformPoint(inverse, vertex);
    if (!local.isFinite) continue;
    if (local.dx < localMinX) localMinX = local.dx;
    if (local.dx > localMaxX) localMaxX = local.dx;
    if (local.dy < localMinY) localMinY = local.dy;
    if (local.dy > localMaxY) localMaxY = local.dy;
  }

  if (!localMinX.isFinite ||
      !localMaxX.isFinite ||
      !localMinY.isFinite ||
      !localMaxY.isFinite) {
    return (visibleFraction: fraction, visibleBounds: Rect.zero);
  }

  final localBounds = Rect.fromLTRB(
    localMinX.clamp(0.0, w),
    localMinY.clamp(0.0, h),
    localMaxX.clamp(0.0, w),
    localMaxY.clamp(0.0, h),
  );
  return (visibleFraction: fraction, visibleBounds: localBounds);
}

List<Offset> _clipAgainstEdge(
  List<Offset> polygon,
  double boundary, {
  required bool isVertical,
  required bool keepGreaterOrEqual,
}) {
  if (polygon.isEmpty) return const [];

  bool isInside(Offset point) {
    final coord = isVertical ? point.dx : point.dy;
    return keepGreaterOrEqual ? coord >= boundary : coord <= boundary;
  }

  Offset intersect(Offset a, Offset b) {
    final aCoord = isVertical ? a.dx : a.dy;
    final bCoord = isVertical ? b.dx : b.dy;
    final denom = bCoord - aCoord;
    if (denom.abs() < 1e-12) return a;
    final t = (boundary - aCoord) / denom;
    return isVertical
        ? Offset(boundary, a.dy + t * (b.dy - a.dy))
        : Offset(a.dx + t * (b.dx - a.dx), boundary);
  }

  final result = <Offset>[];
  var previous = polygon.last;
  var previousInside = isInside(previous);

  for (final current in polygon) {
    final currentInside = isInside(current);
    if (currentInside) {
      if (!previousInside) {
        result.add(intersect(previous, current));
      }
      result.add(current);
    } else if (previousInside) {
      result.add(intersect(previous, current));
    }
    previous = current;
    previousInside = currentInside;
  }

  return result;
}

double _polygonArea(List<Offset> vertices) {
  if (vertices.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final current = vertices[i];
    final next = vertices[(i + 1) % vertices.length];
    sum += current.dx * next.dy - next.dx * current.dy;
  }
  return sum.abs() * 0.5;
}

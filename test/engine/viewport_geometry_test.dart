import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/src/engine/viewport_geometry.dart';

void main() {
  group('isAxisAlignedTransform', () {
    test('returns true for translations, scales, and flips', () {
      expect(isAxisAlignedTransform(Matrix4.identity()), isTrue);
      expect(
        isAxisAlignedTransform(Matrix4.translationValues(12, 34, 0)),
        isTrue,
      );
      expect(
        isAxisAlignedTransform(Matrix4.diagonal3Values(2, -1.5, 1)),
        isTrue,
      );
    });

    test('returns false for rotations, skews, and perspective', () {
      expect(isAxisAlignedTransform(Matrix4.rotationZ(math.pi / 4)), isFalse);
      expect(isAxisAlignedTransform(Matrix4.skewX(0.3)), isFalse);

      final perspective = Matrix4.identity()..setEntry(3, 0, 0.002);
      expect(isAxisAlignedTransform(perspective), isFalse);
    });
  });

  group('computeRotatedVisibility', () {
    test('computes exact visible area when rotated 45 degrees and half clipped',
        () {
      const size = Size(100, 100);
      final transform = Matrix4.translationValues(0, 100, 0)
        ..multiply(Matrix4.rotationZ(math.pi / 4))
        ..multiply(Matrix4.translationValues(-50, -50, 0));

      final result = computeRotatedVisibility(
        size: size,
        transform: transform,
        clipRect: const Rect.fromLTWH(-200, 100, 400, 200),
      );

      expect(result.visibleFraction, closeTo(0.5, 1e-5));
      expect(result.visibleBounds.isEmpty, isFalse);
      expect(result.visibleBounds.width, lessThanOrEqualTo(100.001));
      expect(result.visibleBounds.height, lessThanOrEqualTo(100.001));
    });

    test('short-circuits fully contained and fully disjoint quads', () {
      const size = Size(100, 100);
      final transform = Matrix4.translationValues(100, 100, 0)
        ..rotateZ(math.pi / 6);

      final inside = computeRotatedVisibility(
        size: size,
        transform: transform,
        clipRect: const Rect.fromLTWH(0, 0, 400, 400),
      );
      expect(inside.visibleFraction, 1.0);
      expect(inside.visibleBounds, Offset.zero & size);

      final outside = computeRotatedVisibility(
        size: size,
        transform: transform,
        clipRect: const Rect.fromLTWH(500, 500, 100, 100),
      );
      expect(outside.visibleFraction, 0.0);
      expect(outside.visibleBounds, Rect.zero);
    });

    test('guards degenerate and non-finite transforms', () {
      const size = Size(100, 100);
      final singular = Matrix4.zero()..setEntry(3, 3, 1);
      final nonFinite = Matrix4.translationValues(double.nan, 0, 0);

      expect(
        computeRotatedVisibility(
          size: size,
          transform: singular,
          clipRect: const Rect.fromLTWH(0, 0, 200, 200),
        ).visibleFraction,
        0.0,
      );
      expect(
        computeRotatedVisibility(
          size: size,
          transform: nonFinite,
          clipRect: const Rect.fromLTWH(0, 0, 200, 200),
        ).visibleFraction,
        0.0,
      );
    });
  });
}

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Visibility metrics reported for a widget tracked inside a viewport.
@immutable
class FocusVisibilityInfo {
  /// Creates a [FocusVisibilityInfo] instance.
  const FocusVisibilityInfo({
    required this.visibleFraction,
    required this.size,
    required this.visibleBounds,
  });

  /// Fraction of the widget currently visible in `[0.0, 1.0]`.
  final double visibleFraction;

  /// Laid-out size of the tracked widget in logical pixels.
  final Size size;

  /// Visible portion of the widget in its own local coordinate space.
  final Rect visibleBounds;

  /// Whether any portion of the widget is visible (`visibleFraction > 0.0`).
  bool get isVisible => visibleFraction > 0.0;

  /// Whether the entire widget is visible within floating-point tolerance.
  bool get isFullyVisible => visibleFraction >= 1.0 - 1e-6;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusVisibilityInfo &&
        other.visibleFraction == visibleFraction &&
        other.size == size &&
        other.visibleBounds == visibleBounds;
  }

  @override
  int get hashCode => Object.hash(visibleFraction, size, visibleBounds);

  @override
  String toString() {
    return 'FocusVisibilityInfo('
        'visibleFraction: $visibleFraction, '
        'size: $size, '
        'visibleBounds: $visibleBounds)';
  }
}

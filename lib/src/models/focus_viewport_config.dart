import 'package:flutter/foundation.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';

/// Opt-in configuration for viewport and scroll visibility tracking.
@immutable
class FocusViewportConfig {
  /// Creates a [FocusViewportConfig].
  const FocusViewportConfig({
    this.threshold = 0.5,
    this.minFocusDuration = Duration.zero,
    this.onVisibilityChanged,
  }) : assert(
          threshold > 0.0 && threshold <= 1.0,
          'threshold must be in (0.0, 1.0]',
        );

  /// Minimum visible fraction in `(0.0, 1.0]` required to gain focus.
  final double threshold;

  /// Minimum continuous time above [threshold] before focus is confirmed.
  final Duration minFocusDuration;

  /// Called whenever viewport visibility bounds or fraction change.
  final ValueChanged<FocusVisibilityInfo>? onVisibilityChanged;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusViewportConfig &&
        other.threshold == threshold &&
        other.minFocusDuration == minFocusDuration &&
        other.onVisibilityChanged == onVisibilityChanged;
  }

  @override
  int get hashCode => Object.hash(
        threshold,
        minFocusDuration,
        onVisibilityChanged,
      );
}

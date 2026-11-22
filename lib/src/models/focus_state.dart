import 'package:flutter/foundation.dart';

/// Immutable snapshot of a `FocusOnIt` widget's focus and visibility state.
@immutable
class FocusState {
  /// Creates a [FocusState] snapshot.
  const FocusState({
    required this.isFocused,
    required this.isVisible,
    required this.isInForeground,
    this.visibleFraction = 0.0,
  });

  /// The initial state before focus and visibility have been evaluated.
  static const FocusState initial = FocusState(
    isFocused: false,
    isVisible: false,
    isInForeground: true,
  );

  /// Whether the widget currently has focus.
  ///
  /// True only when [isInForeground] and [isVisible] are both true (and, when
  /// viewport tracking is active, after any configured dwell duration).
  final bool isFocused;

  /// Whether the widget is currently visible in its route and viewport.
  final bool isVisible;

  /// Whether the application is currently in the foreground.
  final bool isInForeground;

  /// The visible fraction of the widget in `[0.0, 1.0]`.
  final double visibleFraction;

  /// Returns a copy of this state with the given fields updated.
  FocusState copyWith({
    bool? isFocused,
    bool? isVisible,
    bool? isInForeground,
    double? visibleFraction,
  }) {
    return FocusState(
      isFocused: isFocused ?? this.isFocused,
      isVisible: isVisible ?? this.isVisible,
      isInForeground: isInForeground ?? this.isInForeground,
      visibleFraction: visibleFraction ?? this.visibleFraction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusState &&
        other.isFocused == isFocused &&
        other.isVisible == isVisible &&
        other.isInForeground == isInForeground &&
        other.visibleFraction == visibleFraction;
  }

  @override
  int get hashCode => Object.hash(
        isFocused,
        isVisible,
        isInForeground,
        visibleFraction,
      );

  @override
  String toString() {
    return 'FocusState('
        'isFocused: $isFocused, '
        'isVisible: $isVisible, '
        'isInForeground: $isInForeground, '
        'visibleFraction: $visibleFraction)';
  }
}

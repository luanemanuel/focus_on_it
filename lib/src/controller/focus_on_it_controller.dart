import 'package:flutter/foundation.dart';
import 'package:focus_on_it/src/models/focus_state.dart';

/// Controller that exposes reactive [FocusState] updates for a `FocusOnIt`.
class FocusOnItController extends ValueNotifier<FocusState> {
  /// Creates a [FocusOnItController] with an optional initial [value].
  // ignore: matching_super_parameters
  FocusOnItController([super.value = FocusState.initial]);

  /// Whether the tracked widget currently has focus.
  bool get isFocused => value.isFocused;

  /// Whether the tracked widget is currently visible in its route and viewport.
  bool get isVisible => value.isVisible;

  /// Whether the application is currently in the foreground.
  bool get isInForeground => value.isInForeground;

  /// The current visible fraction in `[0.0, 1.0]`.
  double get visibleFraction => value.visibleFraction;
}

/// Package-internal helper to sync [controller] when [nextState] changes.
void updateFocusOnItController(
  FocusOnItController controller,
  FocusState nextState,
) {
  if (controller.value != nextState) {
    controller.value = nextState;
  }
}

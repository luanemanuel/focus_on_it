import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/models/focus_state.dart';

enum _FocusScopeAspect { state, focused }

/// Inherited scope exposing [FocusState] updates to descendants.
class FocusOnItScope extends InheritedModel<Object> {
  /// Creates a [FocusOnItScope] carrying [state].
  const FocusOnItScope({
    required this.state,
    required super.child,
    super.key,
  });

  /// The current focus and visibility snapshot for the enclosing subtree.
  final FocusState state;

  /// Returns the enclosing [FocusState], or `null` if no ancestor exists.
  static FocusState? maybeOf(BuildContext context) {
    return InheritedModel.inheritFrom<FocusOnItScope>(
      context,
      aspect: _FocusScopeAspect.state,
    )?.state;
  }

  /// Returns the enclosing [FocusState] and subscribes to state changes.
  static FocusState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw FlutterError(
        'FocusOnIt.of() called with a context that does not contain a '
        'FocusOnIt widget.',
      );
    }
    return state;
  }

  /// Returns whether the enclosing `FocusOnIt` is focused, or `null` if none.
  static bool? maybeIsFocusedOf(BuildContext context) {
    return InheritedModel.inheritFrom<FocusOnItScope>(
      context,
      aspect: _FocusScopeAspect.focused,
    )?.state.isFocused;
  }

  /// Returns whether the enclosing `FocusOnIt` is focused and rebuilds only
  /// when `isFocused` changes.
  static bool isFocusedOf(BuildContext context) {
    final focused = maybeIsFocusedOf(context);
    if (focused == null) {
      throw FlutterError(
        'FocusOnIt.isFocusedOf() called with a context that does not contain '
        'a FocusOnIt widget.',
      );
    }
    return focused;
  }

  @override
  bool updateShouldNotify(FocusOnItScope oldWidget) => oldWidget.state != state;

  @override
  bool updateShouldNotifyDependent(
    FocusOnItScope oldWidget,
    Set<Object> dependencies,
  ) {
    if (dependencies.contains(_FocusScopeAspect.state) &&
        oldWidget.state != state) {
      return true;
    }
    if (dependencies.contains(_FocusScopeAspect.focused) &&
        oldWidget.state.isFocused != state.isFocused) {
      return true;
    }
    return false;
  }
}

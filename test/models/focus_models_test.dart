import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/src/controller/focus_on_it_controller.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';
import 'package:focus_on_it/src/models/focus_state.dart';
import 'package:focus_on_it/src/models/focus_viewport_config.dart';
import 'package:focus_on_it/src/models/focus_visibility_info.dart';

void main() {
  group('FocusState', () {
    test('initial state has expected defaults', () {
      expect(FocusState.initial.isFocused, isFalse);
      expect(FocusState.initial.isVisible, isFalse);
      expect(FocusState.initial.isInForeground, isTrue);
      expect(FocusState.initial.visibleFraction, 0.0);
    });

    test('copyWith updates only provided fields', () {
      const base = FocusState.initial;
      final updated = base.copyWith(
        isFocused: true,
        isVisible: true,
        visibleFraction: 0.75,
      );

      expect(updated.isFocused, isTrue);
      expect(updated.isVisible, isTrue);
      expect(updated.isInForeground, isTrue);
      expect(updated.visibleFraction, 0.75);
    });

    test('supports value equality, hashCode, and toString', () {
      const a = FocusState(
        isFocused: true,
        isVisible: true,
        isInForeground: true,
        visibleFraction: 1,
      );
      const b = FocusState(
        isFocused: true,
        isVisible: true,
        isInForeground: true,
        visibleFraction: 1,
      );
      final c = a.copyWith(isFocused: false);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('isFocused: true'));
      expect(a.toString(), contains('visibleFraction: 1.0'));
    });
  });

  group('FocusVisibilityInfo', () {
    test('computes isVisible and isFullyVisible with tolerance', () {
      const hidden = FocusVisibilityInfo(
        visibleFraction: 0,
        size: Size(100, 100),
        visibleBounds: Rect.zero,
      );
      const partial = FocusVisibilityInfo(
        visibleFraction: 0.4,
        size: Size(100, 100),
        visibleBounds: Rect.fromLTWH(0, 0, 100, 40),
      );
      const nearFull = FocusVisibilityInfo(
        visibleFraction: 0.9999995,
        size: Size(100, 100),
        visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(hidden.isVisible, isFalse);
      expect(hidden.isFullyVisible, isFalse);
      expect(partial.isVisible, isTrue);
      expect(partial.isFullyVisible, isFalse);
      expect(nearFull.isVisible, isTrue);
      expect(nearFull.isFullyVisible, isTrue);
    });

    test('supports value equality, hashCode, and toString', () {
      const a = FocusVisibilityInfo(
        visibleFraction: 0.5,
        size: Size(100, 200),
        visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
      );
      const b = FocusVisibilityInfo(
        visibleFraction: 0.5,
        size: Size(100, 200),
        visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), contains('visibleFraction: 0.5'));
    });
  });

  group('FocusViewportConfig', () {
    test('has sensible defaults and value equality', () {
      void onChanged(FocusVisibilityInfo _) {}

      final a = FocusViewportConfig(onVisibilityChanged: onChanged);
      final b = FocusViewportConfig(onVisibilityChanged: onChanged);
      const custom = FocusViewportConfig(
        threshold: 0.8,
        minFocusDuration: Duration(milliseconds: 250),
      );

      expect(a.threshold, 0.5);
      expect(a.minFocusDuration, Duration.zero);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(custom)));
    });

    test('validates threshold assertions', () {
      expect(
        () => FocusViewportConfig(threshold: 0),
        throwsAssertionError,
      );
      expect(
        () => FocusViewportConfig(threshold: -0.1),
        throwsAssertionError,
      );
      expect(
        () => FocusViewportConfig(threshold: 1.01),
        throwsAssertionError,
      );
    });
  });

  group('FocusAppLifecycleCallbacks', () {
    test('supports value equality and hashCode', () {
      void onHide() {}
      void onShow() {}

      final a = FocusAppLifecycleCallbacks(onHide: onHide, onShow: onShow);
      final b = FocusAppLifecycleCallbacks(onHide: onHide, onShow: onShow);
      const empty = FocusAppLifecycleCallbacks();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(empty)));
    });
  });

  group('FocusOnItController', () {
    test('exposes convenience getters and notifies only on changes', () {
      final controller = FocusOnItController();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.isFocused, isFalse);
      expect(controller.isVisible, isFalse);
      expect(controller.isInForeground, isTrue);
      expect(controller.visibleFraction, 0.0);

      updateFocusOnItController(controller, FocusState.initial);
      expect(notifications, 0);

      const next = FocusState(
        isFocused: true,
        isVisible: true,
        isInForeground: true,
        visibleFraction: 0.8,
      );
      updateFocusOnItController(controller, next);

      expect(notifications, 1);
      expect(controller.isFocused, isTrue);
      expect(controller.isVisible, isTrue);
      expect(controller.isInForeground, isTrue);
      expect(controller.visibleFraction, 0.8);

      updateFocusOnItController(controller, next);
      expect(notifications, 1);
    });
  });
}

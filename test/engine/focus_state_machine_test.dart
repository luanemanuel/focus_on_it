import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/src/engine/focus_state_machine.dart';
import 'package:focus_on_it/src/models/focus_state.dart';

void main() {
  group('FocusStateMachine fast path', () {
    test('transitions on route active/inactive without duplicate calls', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
        onForegroundGained: () => events.add('fgGained'),
        onForegroundLost: () => events.add('fgLost'),
      );
      addTearDown(machine.dispose);

      machine.updateRouteActive(isRouteActive: true);
      expect(events, ['focus', 'visGained']);
      expect(machine.state.isFocused, isTrue);
      expect(machine.state.isVisible, isTrue);
      expect(machine.state.visibleFraction, 1.0);

      machine.updateRouteActive(isRouteActive: true);
      expect(events, ['focus', 'visGained']);

      machine.updateRouteActive(isRouteActive: false);
      expect(events, ['focus', 'visGained', 'unfocus', 'visLost']);
      expect(machine.state.isFocused, isFalse);
      expect(machine.state.isVisible, isFalse);
      expect(machine.state.visibleFraction, 0.0);
    });

    test('handles foreground and background transitions while visible', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
        onForegroundGained: () => events.add('fgGained'),
        onForegroundLost: () => events.add('fgLost'),
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      events.clear();

      machine.updateForeground(isInForeground: false);
      expect(events, ['unfocus', 'fgLost']);
      expect(machine.state.isFocused, isFalse);
      expect(machine.state.isVisible, isTrue);
      expect(machine.state.isInForeground, isFalse);

      machine.updateForeground(isInForeground: true);
      expect(events, ['unfocus', 'fgLost', 'focus', 'fgGained']);
      expect(machine.state.isFocused, isTrue);
      expect(machine.state.isInForeground, isTrue);
    });

    test('suppresses visibility callbacks while in background', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
        onForegroundGained: () => events.add('fgGained'),
        onForegroundLost: () => events.add('fgLost'),
      )..updateForeground(isInForeground: false);
      addTearDown(machine.dispose);

      machine
        ..updateRouteActive(isRouteActive: true)
        ..updateRouteActive(isRouteActive: false)
        ..updateRouteActive(isRouteActive: true);

      expect(events, isEmpty);
      expect(machine.state.isFocused, isFalse);
      expect(machine.state.isVisible, isTrue);

      machine.updateForeground(isInForeground: true);
      expect(events, ['focus', 'fgGained']);
    });

    test('respects triggerOnInit: false on initial visible build', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        triggerOnInit: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(events, isEmpty);
      expect(machine.state.isFocused, isTrue);

      machine
        ..updateRouteActive(isRouteActive: false)
        ..updateRouteActive(isRouteActive: true);

      expect(events, ['unfocus', 'visLost', 'focus', 'visGained']);
    });

    test('triggers focus when triggerOnInit: false starts offscreen', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        triggerOnInit: false,
        onFocus: () => events.add('focus'),
        onVisibilityGained: () => events.add('visGained'),
      )..updateRouteActive(isRouteActive: false);
      addTearDown(machine.dispose);

      expect(events, isEmpty);

      machine.updateRouteActive(isRouteActive: true);
      expect(events, ['focus', 'visGained']);
    });

    test('supports notifyOnDispose: true and false', () {
      var unfocusCount = 0;
      var visLostCount = 0;

      final silent = FocusStateMachine(
        useViewport: false,
        onUnfocus: () => unfocusCount++,
        onVisibilityLost: () => visLostCount++,
      )
        ..updateRouteActive(isRouteActive: true)
        ..dispose();

      expect(silent.isFocused, isTrue);
      expect(unfocusCount, 0);
      expect(visLostCount, 0);

      final noisy = FocusStateMachine(
        useViewport: false,
        notifyOnDispose: true,
        onUnfocus: () => unfocusCount++,
        onVisibilityLost: () => visLostCount++,
      )
        ..updateRouteActive(isRouteActive: true)
        ..dispose();

      expect(noisy.isFocused, isFalse);
      expect(unfocusCount, 1);
      expect(visLostCount, 1);
    });
  });

  group('FocusStateMachine viewport mode', () {
    test('requires both route active and viewport visible to focus', () {
      final states = <FocusState>[];
      final events = <String>[];

      final machine = FocusStateMachine(
        useViewport: true,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
        onStateChanged: states.add,
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(events, isEmpty);
      expect(machine.isFocused, isFalse);

      machine.updateViewport(isViewportVisible: true, visibleFraction: 0.6);
      expect(events, ['focus', 'visGained']);
      expect(machine.state.visibleFraction, 0.6);

      machine.updateViewport(isViewportVisible: true, visibleFraction: 0.9);
      expect(events, ['focus', 'visGained']);
      expect(machine.state.visibleFraction, 0.9);
      expect(states.last.visibleFraction, 0.9);

      machine.updateViewport(isViewportVisible: false, visibleFraction: 0.2);
      expect(events, ['focus', 'visGained', 'unfocus', 'visLost']);
      expect(machine.state.visibleFraction, 0.0);
    });

    test('updateConfig switches between viewport and fast path cleanly', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: true,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(machine.isFocused, isFalse);

      machine.updateConfig(useViewport: false);
      expect(machine.isFocused, isTrue);
      expect(machine.state.visibleFraction, 1.0);
      expect(events, ['focus']);
    });

    test('updateCallbacks swaps callbacks dynamically', () {
      var firstCount = 0;
      var secondCount = 0;
      final machine = FocusStateMachine(
        useViewport: false,
        onFocus: () => firstCount++,
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(firstCount, 1);

      machine
        ..updateCallbacks(onFocus: () => secondCount++)
        ..updateRouteActive(isRouteActive: false)
        ..updateRouteActive(isRouteActive: true);

      expect(firstCount, 1);
      expect(secondCount, 1);
    });
  });

  group('FocusStateMachine dwell duration', () {
    testWidgets('confirms focus only after minFocusDuration elapses',
        (tester) async {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: true,
        minFocusDuration: const Duration(milliseconds: 300),
        onFocus: () => events.add('focus'),
        onVisibilityGained: () => events.add('visGained'),
      )
        ..updateRouteActive(isRouteActive: true)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.7);
      addTearDown(machine.dispose);

      await tester.pump(const Duration(milliseconds: 200));
      expect(events, isEmpty);
      expect(machine.isFocused, isFalse);

      // Updating visibleFraction above threshold must keep the dwell timer.
      machine.updateViewport(isViewportVisible: true, visibleFraction: 0.9);
      await tester.pump(const Duration(milliseconds: 100));

      expect(events, ['focus', 'visGained']);
      expect(machine.isFocused, isTrue);
      expect(machine.state.visibleFraction, 0.9);
    });

    testWidgets('cancels pending dwell timer when visibility is lost early',
        (tester) async {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: true,
        minFocusDuration: const Duration(milliseconds: 300),
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
      )
        ..updateRouteActive(isRouteActive: true)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.8);
      addTearDown(machine.dispose);

      await tester.pump(const Duration(milliseconds: 150));
      machine.updateViewport(isViewportVisible: false, visibleFraction: 0.1);
      await tester.pump(const Duration(milliseconds: 300));

      expect(events, isEmpty);
      expect(machine.isFocused, isFalse);
    });

    testWidgets('cancels pending dwell timer cleanly on dispose',
        (tester) async {
      var focusCount = 0;
      FocusStateMachine(
        useViewport: false,
        minFocusDuration: const Duration(milliseconds: 300),
        onFocus: () => focusCount++,
      )
        ..updateRouteActive(isRouteActive: true)
        ..dispose();

      await tester.pump(const Duration(milliseconds: 500));
      expect(focusCount, 0);
    });

    testWidgets(
        'triggerOnInit: false with useViewport suppresses initial onFocus even '
        'when route activates before first viewport measurement',
        (tester) async {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: true,
        triggerOnInit: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
        onVisibilityGained: () => events.add('visGained'),
        onVisibilityLost: () => events.add('visLost'),
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(events, isEmpty);
      expect(machine.isFocused, isFalse);

      machine.updateViewport(isViewportVisible: true, visibleFraction: 0.9);
      expect(events, isEmpty);
      expect(machine.isFocused, isTrue);

      machine
        ..updateViewport(isViewportVisible: false, visibleFraction: 0.1)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.9);
      expect(events, ['unfocus', 'visLost', 'focus', 'visGained']);
    });

    testWidgets(
        'keeps machine.isVisible in sync with state.isVisible when '
        'backgrounded during active dwell timer', (tester) async {
      final machine = FocusStateMachine(
        useViewport: true,
        minFocusDuration: const Duration(milliseconds: 300),
      )
        ..updateRouteActive(isRouteActive: true)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.8);
      addTearDown(machine.dispose);

      await tester.pump(const Duration(milliseconds: 100));
      expect(machine.isFocused, isFalse);
      expect(machine.isVisible, isFalse);

      machine.updateForeground(isInForeground: false);
      expect(machine.state.isVisible, isTrue);
      expect(machine.isVisible, equals(machine.state.isVisible));

      await tester.pump(const Duration(milliseconds: 400));
      expect(machine.isFocused, isFalse);
    });

    testWidgets(
        'respects applyDwellOnResume false vs true when returning from '
        'background', (tester) async {
      final immediateEvents = <String>[];
      final immediate = FocusStateMachine(
        useViewport: true,
        minFocusDuration: const Duration(milliseconds: 300),
        onFocus: () => immediateEvents.add('focus'),
        onForegroundGained: () => immediateEvents.add('fgGained'),
      )
        ..updateRouteActive(isRouteActive: true)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.8);
      addTearDown(immediate.dispose);

      await tester.pump(const Duration(milliseconds: 300));
      immediateEvents.clear();

      immediate
        ..updateForeground(isInForeground: false)
        ..updateForeground(isInForeground: true);
      expect(immediateEvents, ['focus', 'fgGained']);
      expect(immediate.isFocused, isTrue);

      final delayedEvents = <String>[];
      final delayed = FocusStateMachine(
        useViewport: true,
        minFocusDuration: const Duration(milliseconds: 300),
        applyDwellOnResume: true,
        onFocus: () => delayedEvents.add('focus'),
        onForegroundGained: () => delayedEvents.add('fgGained'),
      )
        ..updateRouteActive(isRouteActive: true)
        ..updateViewport(isViewportVisible: true, visibleFraction: 0.8);
      addTearDown(delayed.dispose);

      await tester.pump(const Duration(milliseconds: 300));
      delayedEvents.clear();

      delayed
        ..updateForeground(isInForeground: false)
        ..updateForeground(isInForeground: true);
      expect(delayedEvents, isEmpty);
      expect(delayed.isFocused, isFalse);

      await tester.pump(const Duration(milliseconds: 299));
      expect(delayedEvents, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(delayedEvents, ['focus', 'fgGained']);
      expect(delayed.isFocused, isTrue);
    });
  });

  group('FocusStateMachine re-entrancy guards', () {
    test('skips secondary callbacks if primary callback disposes machine', () {
      final events = <String>[];
      late final FocusStateMachine machine;
      machine = FocusStateMachine(
        useViewport: false,
        onFocus: () {
          events.add('focus');
          machine.dispose();
        },
        onVisibilityGained: () => events.add('visGained'),
        onForegroundGained: () => events.add('fgGained'),
      );
      machine.updateRouteActive(isRouteActive: true);

      expect(events, ['focus']);
    });

    test('asserts non-negative minFocusDuration', () {
      const negative = Duration(milliseconds: -1);
      expect(
        () => FocusStateMachine(useViewport: true, minFocusDuration: negative),
        throwsAssertionError,
      );

      final machine = FocusStateMachine(useViewport: true);
      addTearDown(machine.dispose);
      expect(
        () => machine.updateConfig(minFocusDuration: negative),
        throwsAssertionError,
      );
    });

    test('switching to viewport while focused avoids spurious unfocus', () {
      final events = <String>[];
      final machine = FocusStateMachine(
        useViewport: false,
        onFocus: () => events.add('focus'),
        onUnfocus: () => events.add('unfocus'),
      )..updateRouteActive(isRouteActive: true);
      addTearDown(machine.dispose);

      expect(events, ['focus']);
      events.clear();

      machine.updateConfig(useViewport: true);
      expect(events, isEmpty);
      expect(machine.isFocused, isTrue);

      machine.updateViewport(isViewportVisible: true, visibleFraction: 0.7);
      expect(events, isEmpty);
      expect(machine.state.visibleFraction, 0.7);
    });
  });
}

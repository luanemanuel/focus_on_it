import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/src/engine/app_lifecycle_tracker.dart';
import 'package:focus_on_it/src/engine/shared_lifecycle_hub.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';

void main() {
  group('AppLifecycleTracker', () {
    testWidgets('tracks mobile foreground transitions without duplicates',
        (tester) async {
      final foregroundEvents = <bool>[];
      final stateHistory = <(AppLifecycleState?, AppLifecycleState)>[];
      var hideCount = 0;
      var showCount = 0;
      var inactiveCount = 0;
      var restartCount = 0;

      final tracker = AppLifecycleTracker(
        binding: tester.binding,
        onForegroundChanged: foregroundEvents.add,
        callbacks: FocusAppLifecycleCallbacks(
          onHide: () => hideCount++,
          onShow: () => showCount++,
          onInactive: () => inactiveCount++,
          onRestart: () => restartCount++,
          onStateChange: (oldState, newState) =>
              stateHistory.add((oldState, newState)),
        ),
      );
      addTearDown(() {
        tracker.dispose();
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      expect(tracker.isInForeground, isTrue);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(foregroundEvents, [false]);
      expect(tracker.isInForeground, isFalse);
      expect(inactiveCount, 1);
      expect(hideCount, 1);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(foregroundEvents, [false, true]);
      expect(tracker.isInForeground, isTrue);
      expect(showCount, 1);
      expect(restartCount, 1);
      expect(stateHistory.last.$2, AppLifecycleState.resumed);
    });

    testWidgets('tracks desktop/web hide transitions without paused state',
        (tester) async {
      final foregroundEvents = <bool>[];
      final tracker = AppLifecycleTracker(
        binding: tester.binding,
        onForegroundChanged: foregroundEvents.add,
      );
      addTearDown(() {
        tracker.dispose();
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      expect(foregroundEvents, [false]);
      expect(tracker.isInForeground, isFalse);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(foregroundEvents, [false, true]);
      expect(tracker.isInForeground, isTrue);
    });

    testWidgets('updateCallbacks swaps lifecycle and exit callbacks cleanly',
        (tester) async {
      final foregroundEvents = <bool>[];
      var firstHideCount = 0;
      var secondHideCount = 0;

      final tracker = AppLifecycleTracker(
        binding: tester.binding,
        onForegroundChanged: foregroundEvents.add,
        callbacks: FocusAppLifecycleCallbacks(
          onHide: () => firstHideCount++,
        ),
      );
      addTearDown(() {
        tracker.dispose();
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      tracker.updateCallbacks(
        FocusAppLifecycleCallbacks(
          onHide: () => secondHideCount++,
          onExitRequested: () async => AppExitResponse.cancel,
        ),
      );

      final response = await tester.binding.handleRequestAppExit();
      expect(response, AppExitResponse.cancel);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(firstHideCount, 0);
      expect(secondHideCount, 1);
      expect(foregroundEvents, [false]);
    });

    testWidgets(
        'SharedLifecycleHub retains binding instance across full unmount and '
        'resubscribe without leaking frame callbacks', (tester) async {
      final hubA = SharedLifecycleHub(tester.binding);
      var watchCalls = 0;

      final trackerA = AppLifecycleTracker(
        binding: tester.binding,
        onForegroundChanged: (_) {},
      )..addAncestorWatcher(() => watchCalls++);

      SchedulerBinding.instance.scheduleFrame();
      await tester.pump();
      expect(watchCalls, 1);

      trackerA.dispose();

      final hubB = SharedLifecycleHub(tester.binding);
      expect(identical(hubA, hubB), isTrue);

      var secondWatchCalls = 0;
      final trackerB = AppLifecycleTracker(
        binding: tester.binding,
        onForegroundChanged: (_) {},
      )..addAncestorWatcher(() => secondWatchCalls++);
      addTearDown(trackerB.dispose);

      SchedulerBinding.instance.scheduleFrame();
      await tester.pump();
      expect(watchCalls, 1);
      expect(secondWatchCalls, 1);
    });
  });
}

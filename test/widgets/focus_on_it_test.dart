import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/focus_on_it.dart';

void main() {
  group('mount', () {
    testWidgets('triggers onFocus and onVisibilityGained on initial build',
        (tester) async {
      final events = <String>[];
      final controller = FocusOnItController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            controller: controller,
            onFocus: () => events.add('focus'),
            onVisibilityGained: () => events.add('visGained'),
            child: const Text('Home'),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(events, ['focus', 'visGained']);
      expect(controller.isFocused, isTrue);
      expect(controller.isVisible, isTrue);
      expect(controller.isInForeground, isTrue);
      expect(controller.visibleFraction, 1.0);
    });

    testWidgets('suppresses initial callbacks when triggerOnInit is false',
        (tester) async {
      final events = <String>[];
      final controller = FocusOnItController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            controller: controller,
            triggerOnInit: false,
            onFocus: () => events.add('focus'),
            onVisibilityGained: () => events.add('visGained'),
            child: const Text('Home'),
          ),
        ),
      );

      expect(events, isEmpty);
      expect(controller.isFocused, isTrue);
    });
  });

  group('navigation & tabs', () {
    testWidgets('fires onUnfocus and onFocus on route push and pop',
        (tester) async {
      final events = <String>[];
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context),
          ),
          home: FocusOnIt(
            onFocus: () => events.add('focus'),
            onUnfocus: () => events.add('unfocus'),
            onVisibilityGained: () => events.add('visGained'),
            onVisibilityLost: () => events.add('visLost'),
            child: const Text('First'),
          ),
        ),
      );

      expect(events, ['focus', 'visGained']);
      events.clear();

      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const Text('Second'),
        ),
      );
      await tester.pump();

      expect(events, ['unfocus', 'visLost']);
      events.clear();

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(events, ['focus', 'visGained']);
    });

    testWidgets(
        'focuses pushed routes with HeroController without extra rebuilds',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final pushedController = FocusOnItController();
      addTearDown(pushedController.dispose);
      final pushedEvents = <String>[];

      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [HeroController()],
          color: const Color(0xFFFFFFFF),
          pageRouteBuilder: <T>(settings, pageBuilder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => pageBuilder(context),
          ),
          home: const Text('Home'),
        ),
      );

      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => FocusOnIt(
            controller: pushedController,
            onFocus: () => pushedEvents.add('focus'),
            child: Builder(
              builder: (context) =>
                  Text('focused=${FocusOnIt.isFocusedOf(context)}'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(pushedEvents, ['focus']);
      expect(pushedController.isFocused, isTrue);
      expect(find.text('focused=true'), findsOneWidget);
    });

    testWidgets('unfocuses behind dialogs when includeDialogs is true',
        (tester) async {
      final events = <String>[];
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context),
          ),
          home: FocusOnIt(
            onFocus: () => events.add('focus'),
            onUnfocus: () => events.add('unfocus'),
            child: const Text('Base'),
          ),
        ),
      );

      events.clear();

      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => const Text('Dialog'),
        ),
      );
      await tester.pump();
      expect(events, ['unfocus']);

      events.clear();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(events, ['focus']);
    });

    testWidgets('keeps focus behind dialogs when includeDialogs is false',
        (tester) async {
      final events = <String>[];
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context),
          ),
          home: FocusOnIt(
            includeDialogs: false,
            onFocus: () => events.add('focus'),
            onUnfocus: () => events.add('unfocus'),
            child: const Text('Base'),
          ),
        ),
      );

      events.clear();

      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => const Text('Dialog'),
        ),
      );
      await tester.pump();
      expect(events, isEmpty);
    });

    testWidgets('tracks TickerMode and IndexedStack switches', (tester) async {
      final tab0Events = <String>[];
      final tab1Events = <String>[];
      var activeIndex = 0;
      late StateSetter setHostState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return IndexedStack(
                index: activeIndex,
                children: [
                  FocusOnIt(
                    onFocus: () => tab0Events.add('focus'),
                    onUnfocus: () => tab0Events.add('unfocus'),
                    child: const Text('Tab 0'),
                  ),
                  FocusOnIt(
                    onFocus: () => tab1Events.add('focus'),
                    onUnfocus: () => tab1Events.add('unfocus'),
                    child: const Text('Tab 1'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(tab0Events, ['focus']);
      expect(tab1Events, isEmpty);

      setHostState(() => activeIndex = 1);
      await tester.pump();

      expect(tab0Events, ['focus', 'unfocus']);
      expect(tab1Events, ['focus']);
    });

    testWidgets('switches active const tabs inside IndexedStack',
        (tester) async {
      final tabTracker = _ConstTabTracker();
      addTearDown(_ConstTabTracker.reset);
      _ConstTabTracker.active = tabTracker;

      var selectedTab = 0;
      late StateSetter updateTab;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateTab = setState;
              return IndexedStack(
                index: selectedTab,
                children: const [
                  _ConstIndexedTab(index: 0),
                  _ConstIndexedTab(index: 1),
                  _ConstIndexedTab(index: 2),
                ],
              );
            },
          ),
        ),
      );

      expect(tabTracker.focused, [true, false, false]);
      expect(tabTracker.focusCounts, [1, 0, 0]);
      expect(tabTracker.unfocusCounts, [0, 0, 0]);

      updateTab(() => selectedTab = 1);
      await tester.pump();

      expect(tabTracker.focused, [false, true, false]);
      expect(tabTracker.focusCounts, [1, 1, 0]);
      expect(tabTracker.unfocusCounts, [1, 0, 0]);

      updateTab(() => selectedTab = 2);
      await tester.pump();

      expect(tabTracker.focused, [false, false, true]);
      expect(tabTracker.focusCounts, [1, 1, 1]);
      expect(tabTracker.unfocusCounts, [1, 1, 0]);
    });

    testWidgets('keeps IndexedStack tabs working after unmount and remount',
        (tester) async {
      final tracker = _ConstTabTracker();
      addTearDown(_ConstTabTracker.reset);
      _ConstTabTracker.active = tracker;

      var selectedTab = 0;
      late StateSetter updateTab;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateTab = setState;
              return IndexedStack(
                index: selectedTab,
                children: const [
                  _ConstIndexedTab(index: 0),
                  _ConstIndexedTab(index: 1),
                ],
              );
            },
          ),
        ),
      );

      expect(tracker.focusCounts, [1, 0, 0]);

      await tester.pumpWidget(const SizedBox.shrink());
      selectedTab = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateTab = setState;
              return IndexedStack(
                index: selectedTab,
                children: const [
                  _ConstIndexedTab(index: 0),
                  _ConstIndexedTab(index: 1),
                ],
              );
            },
          ),
        ),
      );

      expect(tracker.focusCounts, [2, 0, 0]);
      updateTab(() => selectedTab = 1);
      await tester.pump();
      expect(tracker.focusCounts, [2, 1, 0]);
      expect(tracker.focused, [false, true, false]);
    });

    testWidgets('tracks nested Navigator routes inside IndexedStack tabs',
        (tester) async {
      final tab0NavKey = GlobalKey<NavigatorState>();
      final tab1NavKey = GlobalKey<NavigatorState>();
      final tab0RootController = FocusOnItController();
      final tab1RootController = FocusOnItController();
      final tab1DetailController = FocusOnItController();
      addTearDown(tab0RootController.dispose);
      addTearDown(tab1RootController.dispose);
      addTearDown(tab1DetailController.dispose);

      var tab0FocusCount = 0;
      var tab0UnfocusCount = 0;
      var tab1FocusCount = 0;
      var tab1UnfocusCount = 0;
      var selectedTab = 0;
      late StateSetter updateTab;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateTab = setState;
              return IndexedStack(
                index: selectedTab,
                children: [
                  Navigator(
                    key: tab0NavKey,
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => FocusOnIt(
                        controller: tab0RootController,
                        onFocus: () => tab0FocusCount++,
                        onUnfocus: () => tab0UnfocusCount++,
                        child: const Text('Tab 0 Root'),
                      ),
                    ),
                  ),
                  Navigator(
                    key: tab1NavKey,
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => FocusOnIt(
                        controller: tab1RootController,
                        onFocus: () => tab1FocusCount++,
                        onUnfocus: () => tab1UnfocusCount++,
                        child: const Text('Tab 1 Root'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(tab0RootController.isFocused, isTrue);
      expect(tab1RootController.isFocused, isFalse);
      expect(tab0FocusCount, 1);
      expect(tab1FocusCount, 0);

      updateTab(() => selectedTab = 1);
      await tester.pump();

      expect(tab0RootController.isFocused, isFalse);
      expect(tab1RootController.isFocused, isTrue);
      expect(tab0UnfocusCount, 1);
      expect(tab1FocusCount, 1);

      tab1NavKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => FocusOnIt(
            controller: tab1DetailController,
            child: const Text('Tab 1 Detail'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tab1RootController.isFocused, isFalse);
      expect(tab1DetailController.isFocused, isTrue);
      expect(tab0RootController.isFocused, isFalse);
      expect(tab1UnfocusCount, 1);

      tab1NavKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(tab1RootController.isFocused, isTrue);
      expect(tab1FocusCount, 2);

      updateTab(() => selectedTab = 0);
      await tester.pump();

      expect(tab1RootController.isFocused, isFalse);
      expect(tab0RootController.isFocused, isTrue);
      expect(tab0FocusCount, 2);
      expect(tab1UnfocusCount, 2);
    });

    testWidgets(
      'reparenting with GlobalKey between IndexedStack tabs updates focus',
      (tester) async {
        final targetKey = GlobalKey();
        final controller = FocusOnItController();
        addTearDown(controller.dispose);
        var putInActiveTab = false;
        late StateSetter rebuild;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (_, setState) {
                rebuild = setState;
                return IndexedStack(
                  children: [
                    if (putInActiveTab)
                      FocusOnIt(
                        key: targetKey,
                        controller: controller,
                        child: const Text('Moved'),
                      )
                    else
                      const SizedBox.shrink(),
                    if (!putInActiveTab)
                      FocusOnIt(
                        key: targetKey,
                        controller: controller,
                        child: const Text('Moved'),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                );
              },
            ),
          ),
        );

        expect(controller.isFocused, isFalse);

        rebuild(() => putInActiveTab = true);
        await tester.pump();

        expect(controller.isFocused, isTrue);
      },
    );

    testWidgets(
      'reparenting with GlobalKey under a covering dialog stays unfocused',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final targetKey = GlobalKey();
        final controller = FocusOnItController();
        addTearDown(controller.dispose);
        var moveToSecondSlot = false;
        late StateSetter rebuild;

        await tester.pumpWidget(
          WidgetsApp(
            navigatorKey: navigatorKey,
            color: const Color(0xFF000000),
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, __) => builder(context),
            ),
            home: StatefulBuilder(
              builder: (_, setState) {
                rebuild = setState;
                return Row(
                  children: [
                    if (!moveToSecondSlot)
                      FocusOnIt(
                        key: targetKey,
                        controller: controller,
                        child: const Text('Moved'),
                      ),
                    if (moveToSecondSlot)
                      FocusOnIt(
                        key: targetKey,
                        controller: controller,
                        child: const Text('Moved'),
                      ),
                  ],
                );
              },
            ),
          ),
        );

        expect(controller.isFocused, isTrue);

        navigatorKey.currentState!.push<void>(
          PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, __, ___) => const Text('Dialog'),
          ),
        );
        await tester.pump();
        expect(controller.isFocused, isFalse);

        rebuild(() => moveToSecondSlot = true);
        await tester.pump();
        expect(controller.isFocused, isFalse);

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(controller.isFocused, isTrue);
      },
    );
  });

  group('app lifecycle', () {
    testWidgets('tracks foreground transitions and appLifecycle callbacks',
        (tester) async {
      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            onFocus: () => events.add('focus'),
            onUnfocus: () => events.add('unfocus'),
            onForegroundGained: () => events.add('fgGained'),
            onForegroundLost: () => events.add('fgLost'),
            appLifecycle: FocusAppLifecycleCallbacks(
              onHide: () => events.add('hide'),
              onShow: () => events.add('show'),
            ),
            child: const Text('App'),
          ),
        ),
      );
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      events.clear();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(events, ['unfocus', 'fgLost', 'hide']);
      events.clear();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(events, ['show', 'focus', 'fgGained']);
    });

    testWidgets('keeps route focus on inactive and unfocuses on hidden',
        (tester) async {
      final events = <String>[];
      final controller = FocusOnItController();
      addTearDown(controller.dispose);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            controller: controller,
            onFocus: () => events.add('focus'),
            onUnfocus: () => events.add('unfocus'),
            appLifecycle: FocusAppLifecycleCallbacks(
              onInactive: () => events.add('inactive'),
              onHide: () => events.add('hide'),
              onShow: () => events.add('show'),
            ),
            child: const Text('Desktop Window'),
          ),
        ),
      );

      expect(controller.isFocused, isTrue);
      events.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(controller.isFocused, isTrue);
      expect(events, ['inactive']);
      events.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(controller.isFocused, isFalse);
      expect(events, ['unfocus', 'hide']);
      events.clear();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.isFocused, isTrue);
      expect(events, ['show', 'focus']);
    });

    testWidgets('refreshes callbacks on widget update', (tester) async {
      var firstFocusCount = 0;
      var secondFocusCount = 0;
      var firstHideCount = 0;
      var secondHideCount = 0;
      var useSecond = false;
      var enabled = true;
      late StateSetter setHostState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return TickerMode(
                enabled: enabled,
                child: FocusOnIt(
                  onFocus: useSecond
                      ? () => secondFocusCount++
                      : () => firstFocusCount++,
                  appLifecycle: FocusAppLifecycleCallbacks(
                    onHide: useSecond
                        ? () => secondHideCount++
                        : () => firstHideCount++,
                  ),
                  child: const Text('Target'),
                ),
              );
            },
          ),
        ),
      );
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      expect(firstFocusCount, 1);

      setHostState(() {
        useSecond = true;
        enabled = false;
      });
      await tester.pump();

      setHostState(() => enabled = true);
      await tester.pump();

      expect(firstFocusCount, 1);
      expect(secondFocusCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(firstHideCount, 0);
      expect(secondHideCount, 1);
    });

    testWidgets('fires unfocus on dispose only when notifyOnDispose is true',
        (tester) async {
      var silentUnfocus = 0;
      var noisyUnfocus = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            onUnfocus: () => silentUnfocus++,
            child: const Text('Silent'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(silentUnfocus, 0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusOnIt(
            notifyOnDispose: true,
            onUnfocus: () => noisyUnfocus++,
            child: const Text('Noisy'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(noisyUnfocus, 1);
    });
  });

  group('controller & scope', () {
    testWidgets('isFocusedOf rebuilds child only when isFocused changes',
        (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      var focusedChildBuilds = 0;
      var stateChildBuilds = 0;
      bool? latestFocused;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ListView(
              controller: scrollController,
              children: [
                FocusOnIt(
                  viewport: const FocusViewportConfig(threshold: 0.4),
                  child: SizedBox(
                    height: 300,
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            focusedChildBuilds++;
                            latestFocused = FocusOnIt.isFocusedOf(context);
                            return const SizedBox.shrink();
                          },
                        ),
                        Builder(
                          builder: (context) {
                            stateChildBuilds++;
                            FocusOnIt.of(context);
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(latestFocused, isTrue);
      final buildsAtFull = focusedChildBuilds;
      final stateBuildsAtFull = stateChildBuilds;

      scrollController.jumpTo(60);
      await tester.pump();
      await tester.pump();

      expect(latestFocused, isTrue);
      expect(focusedChildBuilds, buildsAtFull);
      expect(stateChildBuilds, greaterThan(stateBuildsAtFull));

      scrollController.jumpTo(250);
      await tester.pump();
      await tester.pump();

      expect(latestFocused, isFalse);
      expect(focusedChildBuilds, greaterThan(buildsAtFull));
    });

    testWidgets('of and isFocusedOf throw FlutterError without ancestor',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(FocusOnIt.maybeOf(context), isNull);
            expect(FocusOnIt.maybeIsFocusedOf(context), isNull);
            expect(() => FocusOnIt.of(context), throwsFlutterError);
            expect(() => FocusOnIt.isFocusedOf(context), throwsFlutterError);
            return const SizedBox.shrink();
          },
        ),
      );
    });
  });

  group('viewport', () {
    testWidgets('tracks threshold and visibleFraction while scrolling ListView',
        (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      final events = <String>[];
      FocusVisibilityInfo? lastInfo;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 600),
                FocusOnIt(
                  onFocus: () => events.add('focus'),
                  onUnfocus: () => events.add('unfocus'),
                  viewport: FocusViewportConfig(
                    onVisibilityChanged: (info) => lastInfo = info,
                  ),
                  child: const SizedBox(width: 400, height: 200),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      );

      expect(events, isEmpty);

      scrollController.jumpTo(80);
      await tester.pump();
      expect(events, isEmpty);
      expect(lastInfo?.visibleFraction, closeTo(0.4, 0.01));

      scrollController.jumpTo(120);
      await tester.pump();
      expect(events, ['focus']);
      expect(lastInfo?.visibleFraction, closeTo(0.6, 0.01));

      scrollController.jumpTo(900);
      await tester.pump();
      expect(events, ['focus', 'unfocus']);
    });

    testWidgets('focuses widgets taller than viewport above threshold',
        (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView(
              children: [
                FocusOnIt(
                  onFocus: () => events.add('focus'),
                  viewport: const FocusViewportConfig(threshold: 0.4),
                  child: const SizedBox(width: 400, height: 1200),
                ),
              ],
            ),
          ),
        ),
      );

      // 600 / 1200 = 0.50, exceeding 0.40.
      expect(events, ['focus']);
    });

    testWidgets('waits for minFocusDuration before focusing', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 600),
                FocusOnIt(
                  onFocus: () => events.add('focus'),
                  onUnfocus: () => events.add('unfocus'),
                  viewport: const FocusViewportConfig(
                    minFocusDuration: Duration(milliseconds: 300),
                  ),
                  child: const SizedBox(width: 400, height: 200),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      );

      scrollController.jumpTo(150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      scrollController.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(events, isEmpty);

      scrollController.jumpTo(150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(events, ['focus']);
    });

    testWidgets(
        'resumes immediately from background when applyDwellOnResume is false',
        (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scrollController = ScrollController();
      final controller = FocusOnItController();
      addTearDown(scrollController.dispose);
      addTearDown(controller.dispose);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      var focusCount = 0;
      var unfocusCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 500),
                FocusOnIt(
                  controller: controller,
                  viewport: const FocusViewportConfig(
                    threshold: 0.6,
                    minFocusDuration: Duration(milliseconds: 250),
                  ),
                  onFocus: () => focusCount++,
                  onUnfocus: () => unfocusCount++,
                  child: const SizedBox(width: 400, height: 200),
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.isFocused, isFalse);
      expect(focusCount, 0);

      scrollController.jumpTo(350);
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.isFocused, isFalse);
      expect(focusCount, 0);

      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.isFocused, isTrue);
      expect(focusCount, 1);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(controller.isFocused, isFalse);
      expect(unfocusCount, 1);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller.isFocused, isTrue);
      expect(focusCount, 2);
    });

    testWidgets('clips visibility at ListView top below a fixed header',
        (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      FocusVisibilityInfo? lastInfo;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              const SizedBox(width: 400, height: 100),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    FocusOnIt(
                      viewport: FocusViewportConfig(
                        onVisibilityChanged: (info) => lastInfo = info,
                      ),
                      child: const SizedBox(width: 400, height: 200),
                    ),
                    const SizedBox(height: 800),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(lastInfo?.visibleFraction, closeTo(1.0, 0.01));

      // 120px scrolled past top clips 120/200px, leaving 0.40 visible.
      scrollController.jumpTo(120);
      await tester.pump();

      expect(lastInfo?.visibleFraction, closeTo(0.4, 0.01));
    });

    testWidgets('tracks visibility in NestedScrollView with pinned header',
        (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final item0Controller = FocusOnItController();
      final item1Controller = FocusOnItController();
      addTearDown(item0Controller.dispose);
      addTearDown(item1Controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FixedHeaderDelegate(height: 80),
                ),
              ],
              body: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      FocusOnIt(
                        controller: item0Controller,
                        viewport: const FocusViewportConfig(),
                        child: const SizedBox(
                          width: 400,
                          height: 260,
                          child: Text('Item 0'),
                        ),
                      ),
                      FocusOnIt(
                        controller: item1Controller,
                        viewport: const FocusViewportConfig(),
                        child: const SizedBox(
                          width: 400,
                          height: 260,
                          child: Text('Item 1'),
                        ),
                      ),
                      const SizedBox(height: 400),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(item0Controller.isFocused, isTrue);
      expect(item1Controller.isFocused, isFalse);

      await tester.drag(find.text('Item 0'), const Offset(0, -240));
      await tester.pump();
      await tester.pump();

      expect(item0Controller.isFocused, isFalse);
      expect(item1Controller.isFocused, isTrue);
    });

    testWidgets('handles MediaQuery updates without dependency loops',
        (tester) async {
      var viewInsetsBottom = 0.0;
      late StateSetter updateInsets;
      FocusVisibilityInfo? lastInfo;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateInsets = setState;
              return MediaQuery(
                data: MediaQueryData(
                  size: const Size(400, 600),
                  viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
                ),
                child: SizedBox(
                  width: 400,
                  height: 600,
                  child: ListView(
                    children: [
                      FocusOnIt(
                        viewport: FocusViewportConfig(
                          onVisibilityChanged: (info) => lastInfo = info,
                        ),
                        child: const SizedBox(width: 400, height: 200),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(lastInfo?.visibleFraction, closeTo(1.0, 0.01));

      updateInsets(() => viewInsetsBottom = 200);
      await tester.pump();
      await tester.pump();

      expect(lastInfo?.visibleFraction, closeTo(1.0, 0.01));
    });

    testWidgets('re-evaluates threshold updates without scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scrollController = ScrollController();
      final controller = FocusOnItController();
      addTearDown(scrollController.dispose);
      addTearDown(controller.dispose);

      var threshold = 0.8;
      late StateSetter updateThreshold;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              updateThreshold = setState;
              return SizedBox(
                width: 400,
                height: 400,
                child: ListView(
                  controller: scrollController,
                  children: [
                    FocusOnIt(
                      controller: controller,
                      viewport: FocusViewportConfig(threshold: threshold),
                      child: const SizedBox(width: 400, height: 200),
                    ),
                    const SizedBox(height: 600),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Clip top 100px so 50% stays visible (below 0.8 threshold).
      scrollController.jumpTo(100);
      await tester.pump();
      expect(controller.isFocused, isFalse);

      updateThreshold(() => threshold = 0.4);
      await tester.pump();
      expect(controller.isFocused, isTrue);
    });

    testWidgets(
      'toggling viewport updates callbacks and controller safely post-frame',
      (tester) async {
        tester.view.physicalSize = const Size(400, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final controller = FocusOnItController();
        addTearDown(controller.dispose);

        var useViewport = false;
        var callbackCount = 0;
        double? controllerFractionDuringCallback;
        late StateSetter rebuildHost;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (_, setState) {
                rebuildHost = setState;
                return SizedBox(
                  width: 400,
                  height: 400,
                  child: ListView(
                    children: [
                      FocusOnIt(
                        controller: controller,
                        viewport: useViewport
                            ? FocusViewportConfig(
                                onVisibilityChanged: (_) {
                                  controllerFractionDuringCallback =
                                      controller.visibleFraction;
                                },
                              )
                            : null,
                        onFocus: () => rebuildHost(() => callbackCount++),
                        onUnfocus: () => rebuildHost(() => callbackCount++),
                        child: const SizedBox(width: 400, height: 200),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        expect(controller.isFocused, isTrue);

        rebuildHost(() => useViewport = true);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(controller.isFocused, isTrue);
        expect(controllerFractionDuringCallback, closeTo(1.0, 0.01));
        expect(callbackCount, 1);

        rebuildHost(() => useViewport = false);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(controller.isFocused, isTrue);
      },
    );

    testWidgets('clips visibility inside non-scrollable ClipRect',
        (tester) async {
      FocusVisibilityInfo? lastInfo;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ClipRect(
              child: SizedBox(
                width: 100,
                height: 200,
                child: OverflowBox(
                  maxWidth: 200,
                  alignment: Alignment.centerLeft,
                  child: FocusOnIt(
                    viewport: FocusViewportConfig(
                      onVisibilityChanged: (info) => lastInfo = info,
                    ),
                    child: const SizedBox(width: 200, height: 200),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(lastInfo?.visibleFraction, closeTo(0.5, 0.01));
      expect(lastInfo?.visibleBounds.width, closeTo(100, 0.5));
    });

    testWidgets('computes exact visible area for rotated widgets',
        (tester) async {
      final controller = FocusOnItController();
      addTearDown(controller.dispose);
      FocusVisibilityInfo? lastInfo;
      final tipOffset = -50 * math.sqrt(2) * 0.5;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ClipRect(
              child: SizedBox(
                width: 400,
                height: 200,
                child: Transform.translate(
                  offset: Offset(0, -100 + tipOffset),
                  child: Center(
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: FocusOnIt(
                        controller: controller,
                        viewport: FocusViewportConfig(
                          threshold: 0.2,
                          onVisibilityChanged: (info) => lastInfo = info,
                        ),
                        child: const SizedBox.square(dimension: 100),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Half of the top half-diamond has area 0.125 (AABB would report 0.25).
      expect(lastInfo?.visibleFraction, closeTo(0.125, 0.01));
      expect(controller.isFocused, isFalse);
    });

    testWidgets('tracks paint-only Transform.translate animations',
        (tester) async {
      final controller = FocusOnItController();
      addTearDown(controller.dispose);
      var offsetX = 0.0;
      late StateSetter moveBox;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: ClipRect(
                child: StatefulBuilder(
                  builder: (_, setState) {
                    moveBox = setState;
                    return Transform.translate(
                      offset: Offset(offsetX, 0),
                      child: FocusOnIt(
                        controller: controller,
                        viewport: const FocusViewportConfig(),
                        child: const SizedBox(width: 200, height: 200),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.isFocused, isTrue);
      expect(controller.visibleFraction, closeTo(1.0, 0.01));

      moveBox(() => offsetX = 140);
      await tester.pumpAndSettle();

      expect(controller.isFocused, isFalse);

      moveBox(() => offsetX = 40);
      await tester.pumpAndSettle();

      expect(controller.isFocused, isTrue);
      expect(controller.visibleFraction, closeTo(0.8, 0.01));
    });
  });
}

class _ConstTabTracker {
  static _ConstTabTracker? active;

  final List<bool> focused = [false, false, false];
  final List<int> focusCounts = [0, 0, 0];
  final List<int> unfocusCounts = [0, 0, 0];

  static void reset() {
    active = null;
  }
}

class _ConstIndexedTab extends StatelessWidget {
  const _ConstIndexedTab({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return FocusOnIt(
      onFocus: () {
        final tracker = _ConstTabTracker.active;
        if (tracker == null) return;
        tracker.focused[index] = true;
        tracker.focusCounts[index]++;
      },
      onUnfocus: () {
        final tracker = _ConstTabTracker.active;
        if (tracker == null) return;
        tracker.focused[index] = false;
        tracker.unfocusCounts[index]++;
      },
      child: Text('Tab $index'),
    );
  }
}

class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FixedHeaderDelegate({required this.height});

  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: const Text('Header'));
  }

  @override
  bool shouldRebuild(_FixedHeaderDelegate oldDelegate) =>
      oldDelegate.height != height;
}

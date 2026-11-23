import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/focus_on_it.dart';

void main() {
  group('FocusOnIt initial mount', () {
    testWidgets('triggers onFocus and onVisibilityGained by default',
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

  group('FocusOnIt navigation & route visibility', () {
    testWidgets('fires onUnfocus and onFocus immediately on Navigator push/pop',
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

    testWidgets('unfocuses on dialog when includeDialogs is true',
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

    testWidgets('keeps focus on dialog when includeDialogs is false',
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

    testWidgets('responds to TickerMode and IndexedStack switches',
        (tester) async {
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
  });

  group('FocusOnIt app lifecycle & widget updates', () {
    testWidgets('handles foreground/background and appLifecycle callbacks',
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

    testWidgets('didUpdateWidget refreshes onFocus and appLifecycle callbacks',
        (tester) async {
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

    testWidgets('notifyOnDispose fires unfocus on teardown only when enabled',
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

  group('FocusOnItController & FocusOnItScope', () {
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

      // Scroll slightly so visibleFraction drops from 1.0 to ~0.8 (still
      // above threshold).
      scrollController.jumpTo(60);
      await tester.pump();
      await tester.pump();

      expect(latestFocused, isTrue);
      expect(focusedChildBuilds, buildsAtFull);
      expect(stateChildBuilds, greaterThan(stateBuildsAtFull));

      // Scroll past threshold so isFocused flips to false.
      scrollController.jumpTo(250);
      await tester.pump();
      await tester.pump();

      expect(latestFocused, isFalse);
      expect(focusedChildBuilds, greaterThan(buildsAtFull));
    });

    testWidgets('of/isFocusedOf throw informative error without ancestor',
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

  group('FocusOnIt viewport mode', () {
    testWidgets('tracks ListView item threshold and visibility bounds',
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

      // Reveal 40% (80px of 200px): below threshold 0.5.
      scrollController.jumpTo(80);
      await tester.pump();
      expect(events, isEmpty);
      expect(lastInfo?.visibleFraction, closeTo(0.4, 0.01));

      // Reveal 60% (120px of 200px): crosses threshold 0.5.
      scrollController.jumpTo(120);
      await tester.pump();
      expect(events, ['focus']);
      expect(lastInfo?.visibleFraction, closeTo(0.6, 0.01));

      // Scroll completely off top edge.
      scrollController.jumpTo(900);
      await tester.pump();
      expect(events, ['focus', 'unfocus']);
    });

    testWidgets('focuses widgets larger than the viewport above threshold',
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

      // 600 / 1200 = 0.5 >= 0.4 -> focuses despite being taller than viewport.
      expect(events, ['focus']);
    });

    testWidgets(
        'minFocusDuration ignores quick scroll passes and confirms dwell',
        (tester) async {
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

      // Scroll into view briefly for 100ms, then scroll back out.
      scrollController.jumpTo(150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      scrollController.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(events, isEmpty);

      // Scroll into view and stay for full 300ms.
      scrollController.jumpTo(150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(events, ['focus']);
    });

    testWidgets('clips visibility at ListView top below a fixed header bar',
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

      // Scroll 120px past the ListView top edge (below the 100px header):
      // 80px of the 200px child stays visible -> 0.40, not 0.90.
      scrollController.jumpTo(120);
      await tester.pump();

      expect(lastInfo?.visibleFraction, closeTo(0.4, 0.01));
    });
  });

  group('FocusOnIt regression fixes', () {
    testWidgets(
        'pushed route with HeroController focuses immediately without rebuild',
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

    testWidgets(
        'IndexedStack with const children focuses active tab and switches '
        'cleanly', (tester) async {
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

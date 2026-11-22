import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/focus_on_it.dart';
import 'package:visibility_detector/visibility_detector.dart';

Map<String, double> _summarize(List<double> samples, {required int decimals}) {
  final sorted = List<double>.from(samples)..sort();
  final n = sorted.length;
  final mean = samples.reduce((a, b) => a + b) / n;
  final median = n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;

  var variance = 0.0;
  if (n > 1) {
    for (final value in samples) {
      final diff = value - mean;
      variance += diff * diff;
    }
    variance /= n - 1;
  }
  final stddev = math.sqrt(variance);

  final rank = 0.95 * (n - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  final p95 = sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);

  double round(double v) => double.parse(v.toStringAsFixed(decimals));

  return {
    'median': round(median),
    'mean': round(mean),
    'stddev': round(stddev),
    'p95': round(p95),
    'min': round(sorted.first),
    'max': round(sorted.last),
  };
}

void main() {
  const latencyWarmup = 5;
  const latencySamplesCount = 20;
  const mountWarmup = 5;
  const mountSamplesCount = 20;
  const mountWidgetCount = 250;
  const scrollWarmup = 30;
  const scrollSamplesCount = 120;
  const scrollWidgetCount = 100;

  testWidgets('benchmark published focus_on_it 2.0.1', (tester) async {
    final routeSamplesMs = <double>[];
    for (var i = 0; i < latencyWarmup + latencySamplesCount; i++) {
      final navigatorKey = GlobalKey<NavigatorState>();
      var focused = false;
      var unfocused = false;

      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, pageBuilder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => pageBuilder(context),
          ),
          home: FocusOnIt(
            key: UniqueKey(),
            onFocus: () => focused = true,
            onUnfocus: () => unfocused = true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(focused, isTrue);

      VisibilityDetectorController.instance.updateInterval =
          const Duration(milliseconds: 500);

      final initialSw = Stopwatch()..start();
      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF000000)),
        ),
      );
      await tester.pump();
      initialSw.stop();

      var simulatedMs = 0;
      var triggerFrameMs = initialSw.elapsedMicroseconds / 1000.0;
      while (!unfocused && simulatedMs < 1500) {
        final stepSw = Stopwatch()..start();
        simulatedMs += 1;
        await tester.pump(const Duration(milliseconds: 1));
        stepSw.stop();
        triggerFrameMs = stepSw.elapsedMicroseconds / 1000.0;
      }

      expect(unfocused, isTrue);
      if (i >= latencyWarmup) {
        routeSamplesMs.add(simulatedMs + triggerFrameMs);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    var dialogUnfocused = false;
    final dialogNav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        navigatorKey: dialogNav,
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, pageBuilder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, __) => pageBuilder(context),
        ),
        home: FocusOnIt(
          key: UniqueKey(),
          onUnfocus: () => dialogUnfocused = true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
    dialogNav.currentState!.push<void>(
      RawDialogRoute<void>(
        transitionDuration: Duration.zero,
        barrierColor: const Color(0x88000000),
        pageBuilder: (_, __, ___) => const Center(
          child: SizedBox(
            width: 240,
            height: 140,
            child: ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var s = 0; s < 1500 && !dialogUnfocused; s++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    final dialogSamplesMs = <double>[];
    if (dialogUnfocused) {
      for (var i = 0; i < latencyWarmup + latencySamplesCount; i++) {
        final nav = GlobalKey<NavigatorState>();
        var unfocused = false;
        await tester.pumpWidget(
          WidgetsApp(
            navigatorKey: nav,
            color: const Color(0xFF000000),
            pageRouteBuilder: <T>(settings, pageBuilder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, __) => pageBuilder(context),
            ),
            home: FocusOnIt(
              key: UniqueKey(),
              onUnfocus: () => unfocused = true,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        VisibilityDetectorController.instance.updateInterval =
            const Duration(milliseconds: 500);
        final initialSw = Stopwatch()..start();
        nav.currentState!.push<void>(
          RawDialogRoute<void>(
            transitionDuration: Duration.zero,
            barrierColor: const Color(0x88000000),
            pageBuilder: (_, __, ___) => const Center(
              child: SizedBox(
                width: 240,
                height: 140,
                child: ColoredBox(color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        );
        await tester.pump();
        initialSw.stop();
        var simulatedMs = 0;
        var triggerFrameMs = initialSw.elapsedMicroseconds / 1000.0;
        while (!unfocused && simulatedMs < 1500) {
          final stepSw = Stopwatch()..start();
          simulatedMs += 1;
          await tester.pump(const Duration(milliseconds: 1));
          stepSw.stop();
          triggerFrameMs = stepSw.elapsedMicroseconds / 1000.0;
        }
        if (unfocused && i >= latencyWarmup) {
          dialogSamplesMs.add(simulatedMs + triggerFrameMs);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    }

    final mountSamplesMs = <double>[];
    for (var i = 0; i < mountWarmup + mountSamplesCount; i++) {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(
                mountWidgetCount,
                (index) => FocusOnIt(
                  key: ValueKey('v2_mu_${i}_$index'),
                  onFocus: () {},
                  onUnfocus: () {},
                  child: const SizedBox(width: 20, height: 20),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      sw.stop();

      if (i >= mountWarmup) {
        mountSamplesMs.add(sw.elapsedMicroseconds / 1000.0);
      }
      await tester.pump(const Duration(seconds: 1));
    }

    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final scrollController = ScrollController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: List.generate(
                scrollWidgetCount,
                (index) => FocusOnIt(
                  key: ValueKey('v2_sc_$index'),
                  onFocus: () {},
                  onUnfocus: () {},
                  child: const SizedBox(width: 400, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < scrollWarmup; i++) {
      scrollController.jumpTo(i.isEven ? 0 : 120);
      await tester.pump();
    }

    final scrollSamplesMs = <double>[];
    for (var i = 0; i < scrollSamplesCount; i++) {
      final sw = Stopwatch()..start();
      scrollController.jumpTo(i.isEven ? 0 : 120);
      await tester.pump();
      sw.stop();
      scrollSamplesMs.add(sw.elapsedMicroseconds / 1000.0);
    }

    scrollController.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    final outFile = File('../../results/focus_on_it_v2.json');
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'name': 'focus_on_it 2.0.1',
        'platform':
            '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
        'cpu_cores': Platform.numberOfProcessors,
        'dart_version': Platform.version.split(' ').first,
        'mode': 'isolated_runner_concurrency_1',
        'latency_samples_count': latencySamplesCount,
        'mount_samples_count': mountSamplesCount,
        'mount_widgets_count': mountWidgetCount,
        'scroll_samples_count': scrollSamplesCount,
        'scroll_widgets_count': scrollWidgetCount,
        'route_latency_ms': _summarize(routeSamplesMs, decimals: 3),
        'dialog_detection_ms': dialogSamplesMs.length == latencySamplesCount
            ? {
                'supported': true,
                ..._summarize(dialogSamplesMs, decimals: 3),
              }
            : {'supported': false},
        'mount_unmount_250_ms': _summarize(mountSamplesMs, decimals: 3),
        'scroll_frame_100_ms': _summarize(scrollSamplesMs, decimals: 3),
      }),
    );
  });
}

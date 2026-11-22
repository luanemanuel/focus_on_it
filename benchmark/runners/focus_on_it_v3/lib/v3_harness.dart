import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/focus_on_it.dart';

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

Future<List<double>> _measureScrollFrames({
  required WidgetTester tester,
  required String prefix,
  required int count,
  required int warmupFrames,
  required int sampleFrames,
  required FocusViewportConfig? viewport,
}) async {
  final scrollController = ScrollController();
  var tick = 0;
  late StateSetter setHostState;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return SizedBox(
            width: 400,
            height: 600,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: List.generate(
                  count,
                  (index) => FocusOnIt(
                    key: ValueKey('${prefix}_${count}_$index'),
                    onFocus: () {},
                    onUnfocus: () {},
                    viewport: viewport,
                    child: SizedBox(
                      width: 400,
                      height: 40,
                      child: Text('Item $index ($tick)'),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();

  for (var i = 0; i < warmupFrames; i++) {
    setHostState(() => tick++);
    scrollController.jumpTo(tick.isEven ? 0 : 120);
    await tester.pump();
  }

  final samplesUs = <double>[];
  for (var i = 0; i < sampleFrames; i++) {
    final sw = Stopwatch()..start();
    setHostState(() => tick++);
    scrollController.jumpTo(tick.isEven ? 0 : 120);
    await tester.pump();
    sw.stop();
    samplesUs.add(sw.elapsedMicroseconds.toDouble());
  }

  scrollController.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  return samplesUs;
}

Future<void> runV3Benchmark({
  required WidgetTester tester,
  required String name,
  required String outputFileName,
  FocusViewportConfig? viewport,
}) async {
  const latencyWarmup = 5;
  const latencySamplesCount = 20;
  const overheadWarmup = 30;
  const overheadSamplesCount = 120;
  const trackedWidgetCount = 100;
  const scalabilityCounts = [10, 50, 100, 250];
  const scalabilityWarmup = 15;
  const scalabilitySamplesCount = 40;

  final latencySamplesMs = <double>[];
  final totalLatencyRuns = latencyWarmup + latencySamplesCount;

  for (var i = 0; i < totalLatencyRuns; i++) {
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
          viewport: viewport,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(focused, isTrue, reason: '$name failed initial focus');

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

    expect(unfocused, isTrue, reason: '$name failed unfocus detection');
    if (i >= latencyWarmup) {
      latencySamplesMs.add(simulatedMs + triggerFrameMs);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  final overheadSamplesUs = await _measureScrollFrames(
    tester: tester,
    prefix: outputFileName,
    count: trackedWidgetCount,
    warmupFrames: overheadWarmup,
    sampleFrames: overheadSamplesCount,
    viewport: viewport,
  );

  final scalability = <String, Map<String, double>>{};
  for (final count in scalabilityCounts) {
    final samplesUs = await _measureScrollFrames(
      tester: tester,
      prefix: '${outputFileName}_scale',
      count: count,
      warmupFrames: scalabilityWarmup,
      sampleFrames: scalabilitySamplesCount,
      viewport: viewport,
    );
    final stats = _summarize(samplesUs, decimals: 1);
    scalability['$count'] = {
      'median': stats['median']!,
      'p95': stats['p95']!,
      'stddev': stats['stddev']!,
    };
  }

  final outFile = File('../../results/$outputFileName.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'platform':
          '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      'cpu_cores': Platform.numberOfProcessors,
      'dart_version': Platform.version.split(' ').first,
      'mode': 'isolated_runner_concurrency_1',
      'latency_samples_count': latencySamplesCount,
      'overhead_samples_count': overheadSamplesCount,
      'widgets_count': trackedWidgetCount,
      'detection_latency_ms': _summarize(latencySamplesMs, decimals: 3),
      'frame_overhead_us': _summarize(overheadSamplesUs, decimals: 1),
      'scalability_us': scalability,
    }),
  );
}

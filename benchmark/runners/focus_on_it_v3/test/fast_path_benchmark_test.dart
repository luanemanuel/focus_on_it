import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it_v3_benchmark/v3_harness.dart';

void main() {
  testWidgets('benchmark focus_on_it 3.0 (Fast Path)', (tester) async {
    await runV3Benchmark(
      tester: tester,
      name: 'focus_on_it 3.0 (Fast Path)',
      outputFileName: 'focus_on_it_v3_fast_path',
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_on_it/focus_on_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> createWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FocusOnIt(
          child: Placeholder(),
        ),
      ),
    );
  }

  testWidgets('Sanity test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await createWidget(tester);
      await tester.pumpAndSettle();
    });

    expect(find.byType(FocusOnIt), findsOneWidget);
    expect(find.byType(Placeholder), findsOneWidget);
  });
}

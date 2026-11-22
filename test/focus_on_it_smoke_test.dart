import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_on_it/focus_on_it.dart';

void main() {
  testWidgets('FocusOnIt renders its child widget', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: FocusOnIt(
          child: Text('Focus target'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focus target'), findsOneWidget);
  });
}

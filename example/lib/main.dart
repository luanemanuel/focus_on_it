import 'package:flutter/material.dart';
import 'package:focus_on_it/focus_on_it.dart';
import 'package:logger/logger.dart';

class FocusOnItExample extends StatelessWidget {
  const FocusOnItExample({super.key});

  @override
  Widget build(BuildContext context) => FocusOnIt(
        onUnfocus: () {
          /// This function is triggered when [onVisibilityLost] or
          /// [onForegroundLost] is called
          ///
          /// Equivalent to onPause() on Android or viewDidDisappear() on IOS.
          logger.i('Focus Lost.');
        },
        onFocus: () {
          /// This function is triggered when [onVisibilityGained] or
          /// [onForegroundGained] is called
          ///
          /// Equivalent to onResume() on Android or viewDidAppear() on IOS.
          logger.i('Focus Gained.');
        },
        onVisibilityLost: () {
          /// The widget is no longer visible within your app.
          logger.i('Visibility Lost.');
        },
        onVisibilityGained: () {
          /// The widget is now visible within your app.
          logger.i('Visibility Gained.');
        },
        onForegroundLost: () {
          /// The user sent your app to the background by opening another app
          /// or turned off the device's screen while your widget was visible.
          logger.i('Foreground Lost.');
        },
        onForegroundGained: () {
          /// The user switched back to your app or turned the device\'s screen
          /// back on while your widget was visible.
          logger.i('Foreground Gained.');
        },
        child: Material(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Send the app to the background or push another page and '
                  'watch the console.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    final route = MaterialPageRoute(
                      builder: (_) => const TestPage(),
                    );
                    Navigator.of(context).push(route);
                  },
                  child: const Text(
                    'PUSH ANOTHER PAGE',
                  ),
                )
              ],
            ),
          ),
        ),
      );
}

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Look at the console and return to the first screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
              ),
            ),
          ),
        ),
      );
}

Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    printTime: false,
  ),
);

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FocusOnItExample(),
    ),
  );
}

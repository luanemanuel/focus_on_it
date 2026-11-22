// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:focus_on_it_example/examples/indexed_stack_tabs_example.dart';
import 'package:focus_on_it_example/examples/route_lifecycle_example.dart';
import 'package:focus_on_it_example/examples/viewport_feed_example.dart';

void main() {
  runApp(const FocusOnItExampleApp());
}

class FocusOnItExampleApp extends StatelessWidget {
  const FocusOnItExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Focus on It Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A66C2),
        ),
        useMaterial3: true,
      ),
      home: const _ExampleListPage(),
    );
  }
}

class _ExampleListPage extends StatelessWidget {
  const _ExampleListPage();

  @override
  Widget build(BuildContext context) {
    final examples = [
      (
        title: 'Route, Dialog & App Lifecycle',
        subtitle: 'Navigator push/pop, dialogs, sheets, and foreground events.',
        builder: (_) => const RouteLifecycleExample(),
      ),
      (
        title: 'Viewport Feed Visibility',
        subtitle: 'ListView cards using threshold and minFocusDuration.',
        builder: (_) => const ViewportFeedExample(),
      ),
      (
        title: 'IndexedStack Tabs',
        subtitle: 'Automatic focus switching across IndexedStack tabs.',
        builder: (_) => const IndexedStackTabsExample(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Focus on It 3.0 Examples')),
      body: ListView.separated(
        itemCount: examples.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = examples[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: item.builder),
            ),
          );
        },
      ),
    );
  }
}

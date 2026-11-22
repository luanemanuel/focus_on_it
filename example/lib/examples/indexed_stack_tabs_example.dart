import 'package:focus_on_it/focus_on_it.dart';
import 'package:material_ui/material_ui.dart';

class IndexedStackTabsExample extends StatefulWidget {
  const IndexedStackTabsExample({super.key});

  @override
  State<IndexedStackTabsExample> createState() =>
      _IndexedStackTabsExampleState();
}

class _IndexedStackTabsExampleState extends State<IndexedStackTabsExample> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IndexedStack Tabs')),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _TabPane(label: 'Explore'),
          _TabPane(label: 'Favorites'),
          _TabPane(label: 'Profile'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _TabPane extends StatefulWidget {
  const _TabPane({required this.label});

  final String label;

  @override
  State<_TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<_TabPane> {
  bool _focused = false;
  int _focusCount = 0;
  int _unfocusCount = 0;

  @override
  Widget build(BuildContext context) {
    return FocusOnIt(
      onFocus: () {
        if (!mounted) return;
        setState(() {
          _focused = true;
          _focusCount++;
        });
      },
      onUnfocus: () {
        if (!mounted) return;
        setState(() {
          _focused = false;
          _unfocusCount++;
        });
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.label} Tab',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(_focused ? 'Status: Focused' : 'Status: Unfocused'),
            const SizedBox(height: 8),
            Text(
                'onFocus calls: $_focusCount | onUnfocus calls: $_unfocusCount'),
          ],
        ),
      ),
    );
  }
}

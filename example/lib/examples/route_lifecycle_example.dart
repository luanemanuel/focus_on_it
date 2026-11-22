import 'package:focus_on_it/focus_on_it.dart';
import 'package:material_ui/material_ui.dart';

class RouteLifecycleExample extends StatefulWidget {
  const RouteLifecycleExample({super.key});

  @override
  State<RouteLifecycleExample> createState() => _RouteLifecycleExampleState();
}

class _RouteLifecycleExampleState extends State<RouteLifecycleExample> {
  final FocusOnItController _controller = FocusOnItController();
  final List<String> _events = [];
  bool _includeDialogs = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _logEvent(String event) {
    if (!mounted) return;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');

    setState(() {
      _events.insert(0, '$hh:$mm:$ss.$ms  $event');
      if (_events.length > 40) {
        _events.removeLast();
      }
    });
  }

  Future<void> _pushSecondRoute() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const _SecondRoutePage(),
      ),
    );
  }

  Future<void> _openDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sample Dialog'),
        content: Text(
          _includeDialogs
              ? 'With includeDialogs: true, the screen behind lost focus.'
              : 'With includeDialogs: false, the screen behind kept focus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBottomSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modal Bottom Sheet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _includeDialogs
                    ? 'The underlying screen unfocused while this sheet is open.'
                    : 'includeDialogs is false, so underlying focus stayed active.',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route & Lifecycle')),
      body: FocusOnIt(
        controller: _controller,
        includeDialogs: _includeDialogs,
        onFocus: () => _logEvent('onFocus'),
        onUnfocus: () => _logEvent('onUnfocus'),
        onVisibilityGained: () => _logEvent('onVisibilityGained'),
        onVisibilityLost: () => _logEvent('onVisibilityLost'),
        onForegroundGained: () => _logEvent('onForegroundGained'),
        onForegroundLost: () => _logEvent('onForegroundLost'),
        appLifecycle: FocusAppLifecycleCallbacks(
          onHide: () => _logEvent('appLifecycle.onHide'),
          onShow: () => _logEvent('appLifecycle.onShow'),
          onInactive: () => _logEvent('appLifecycle.onInactive'),
          onStateChange: (oldState, newState) => _logEvent(
            'state: ${oldState?.name ?? 'null'} -> ${newState.name}',
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FocusStatusBadge(),
              const SizedBox(height: 8),
              ValueListenableBuilder<FocusState>(
                valueListenable: _controller,
                builder: (_, state, __) => Text(
                  'Controller: visible=${state.isVisible}, '
                  'foreground=${state.isInForeground}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unfocus on dialogs & sheets'),
                subtitle: const Text('includeDialogs'),
                value: _includeDialogs,
                onChanged: (value) => setState(() => _includeDialogs = value),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _pushSecondRoute,
                    child: const Text('Push Route'),
                  ),
                  OutlinedButton(
                    onPressed: _openDialog,
                    child: const Text('Show Dialog'),
                  ),
                  OutlinedButton(
                    onPressed: _openBottomSheet,
                    child: const Text('Bottom Sheet'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Event Log',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed:
                        _events.isEmpty ? null : () => setState(_events.clear),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: _events.isEmpty
                    ? const Center(child: Text('Waiting for events...'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _events[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusStatusBadge extends StatelessWidget {
  const _FocusStatusBadge();

  @override
  Widget build(BuildContext context) {
    final isFocused = FocusOnIt.isFocusedOf(context);
    final color = isFocused ? const Color(0xFF1B7F37) : const Color(0xFFB42318);
    final backgroundColor =
        isFocused ? const Color(0x1F1B7F37) : const Color(0x1FB42318);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            isFocused ? Icons.check_circle : Icons.pause_circle,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isFocused ? 'Screen is Focused' : 'Screen is Unfocused',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SecondRoutePage extends StatelessWidget {
  const _SecondRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Route')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'While this route is on top, the previous screen is unfocused.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

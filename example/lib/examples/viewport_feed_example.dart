// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:focus_on_it/focus_on_it.dart';

class ViewportFeedExample extends StatelessWidget {
  const ViewportFeedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viewport Feed')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _FeedItemCard(index: index),
      ),
    );
  }
}

class _FeedItemCard extends StatefulWidget {
  const _FeedItemCard({required this.index});

  final int index;

  @override
  State<_FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<_FeedItemCard> {
  bool _isFocused = false;
  double _visibleFraction = 0;

  @override
  Widget build(BuildContext context) {
    return FocusOnIt(
      onFocus: () {
        if (mounted) setState(() => _isFocused = true);
      },
      onUnfocus: () {
        if (mounted) setState(() => _isFocused = false);
      },
      viewport: FocusViewportConfig(
        threshold: 0.6,
        minFocusDuration: const Duration(milliseconds: 250),
        onVisibilityChanged: (info) {
          if (mounted) {
            setState(() => _visibleFraction = info.visibleFraction);
          }
        },
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Feed Card #${widget.index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Chip(
                    label: Text(_isFocused ? 'Active (playing)' : 'Paused'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Visible: ${(_visibleFraction * 100).round()}%'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _visibleFraction),
              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}

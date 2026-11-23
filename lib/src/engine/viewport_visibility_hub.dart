import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Direct allocation-free client interface for [ViewportVisibilityHub].
abstract interface class ViewportTrackerClient {
  /// Called when an enclosing `ScrollPosition` scrolls or window metrics
  /// change.
  void scheduleMeasurement();

  /// Executes batched viewport visibility measurement using shared per-flush
  /// caches and reusable scratch storage.
  void flushMeasurement(
    Map<ScrollableState, Rect> scrollableRectCache,
    Map<FlutterView, Rect> windowBoundsCache,
    Map<RenderObject, Matrix4> ancestorTransformCache,
    Map<RenderObject, Rect> ancestorClipCache,
    List<RenderObject> clipTrailScratch,
    Matrix4 scratchTransform,
  );
}

class _ScrollPositionGroup {
  _ScrollPositionGroup(this.position, this.onScroll) {
    position.addListener(onScroll);
  }

  final ScrollPosition position;
  final VoidCallback onScroll;
  final Set<ViewportTrackerClient> trackers = {};

  void dispose() {
    position.removeListener(onScroll);
    trackers.clear();
  }
}

/// Shared observer, scroll group coordinator, and post-frame batch hub for
/// [WidgetsBinding] instances.
class ViewportVisibilityHub with WidgetsBindingObserver {
  /// Returns the shared [ViewportVisibilityHub] for the active binding.
  factory ViewportVisibilityHub() {
    final binding = WidgetsBinding.instance;
    if (identical(binding, _lastBinding)) {
      return _lastHub;
    }
    final hub = _hubs[binding] ??= ViewportVisibilityHub._(binding);
    _lastBinding = binding;
    _lastHub = hub;
    return hub;
  }

  ViewportVisibilityHub._(this._binding) {
    _flushCallback = _flush;
  }

  static final Expando<ViewportVisibilityHub> _hubs =
      Expando<ViewportVisibilityHub>();
  static WidgetsBinding? _lastBinding;
  static late ViewportVisibilityHub _lastHub;

  final WidgetsBinding _binding;
  final Set<ViewportTrackerClient> _metricsListeners = {};
  final Map<ScrollPosition, _ScrollPositionGroup> _scrollGroups = {};
  final Map<ScrollableState, ScrollableState?> _outerScrollableCache = {};
  final Map<ScrollableState, Rect> _scrollableRectCache = {};
  final Map<FlutterView, Rect> _windowBoundsCache = {};
  final Map<RenderObject, Matrix4> _ancestorTransformCache = {};
  final Map<RenderObject, Rect> _ancestorClipCache = {};
  final List<RenderObject> _clipTrailScratch = [];
  final Matrix4 _scratchTransform = Matrix4.identity();

  List<ViewportTrackerClient> _pendingTrackers = [];
  List<ViewportTrackerClient> _flushingTrackers = [];
  late final void Function(Duration) _flushCallback;

  bool _observerAttached = false;
  bool _flushScheduled = false;

  /// Registers [client] to re-measure when binding window metrics change.
  void addMetricsTracker(ViewportTrackerClient client) {
    if (_metricsListeners.add(client) && !_observerAttached) {
      _binding.addObserver(this);
      _observerAttached = true;
    }
  }

  /// Unregisters a previously registered metrics [client].
  void removeMetricsTracker(ViewportTrackerClient client) {
    if (_metricsListeners.remove(client) &&
        _metricsListeners.isEmpty &&
        _observerAttached) {
      _binding.removeObserver(this);
      _observerAttached = false;
    }
  }

  /// Subscribes [client] to scroll notifications from [position] through a
  /// single shared listener per [ScrollPosition].
  void attachScrollPosition(
    ScrollPosition position,
    ViewportTrackerClient client,
  ) {
    var group = _scrollGroups[position];
    if (group == null) {
      group = _ScrollPositionGroup(
        position,
        () => _notifyScrollGroup(position),
      );
      _scrollGroups[position] = group;
    }
    group.trackers.add(client);
  }

  /// Unsubscribes [client] from [position], removing the platform listener when
  /// the last tracker detaches.
  void detachScrollPosition(
    ScrollPosition position,
    ViewportTrackerClient client,
  ) {
    final group = _scrollGroups[position];
    if (group == null) return;
    group.trackers.remove(client);
    if (group.trackers.isEmpty) {
      _scrollGroups.remove(position);
      group.dispose();
    }
  }

  /// Resolves and caches the nearest enclosing [ScrollableState] above
  /// [scrollable] within the current frame.
  ScrollableState? findOuterScrollable(ScrollableState scrollable) {
    if (_outerScrollableCache.containsKey(scrollable)) {
      return _outerScrollableCache[scrollable];
    }
    final outer = scrollable.context.findAncestorStateOfType<ScrollableState>();
    _outerScrollableCache[scrollable] = outer;
    return outer;
  }

  /// Enqueues [client] to run on the next post-frame batch flush.
  void scheduleTracker(ViewportTrackerClient client) {
    _pendingTrackers.add(client);
    if (_flushScheduled) return;
    _flushScheduled = true;
    _binding.addPostFrameCallback(_flushCallback);
  }

  @override
  void didChangeMetrics() {
    for (final client in _metricsListeners) {
      client.scheduleMeasurement();
    }
  }

  void _notifyScrollGroup(ScrollPosition position) {
    final group = _scrollGroups[position];
    if (group == null) return;
    for (final tracker in group.trackers) {
      tracker.scheduleMeasurement();
    }
  }

  void _flush(Duration _) {
    _flushScheduled = false;
    if (_pendingTrackers.isEmpty) {
      if (_outerScrollableCache.isNotEmpty) {
        _outerScrollableCache.clear();
      }
      return;
    }

    final batch = _pendingTrackers;
    _pendingTrackers = _flushingTrackers;
    _flushingTrackers = batch;

    try {
      for (var i = 0; i < batch.length; i++) {
        batch[i].flushMeasurement(
          _scrollableRectCache,
          _windowBoundsCache,
          _ancestorTransformCache,
          _ancestorClipCache,
          _clipTrailScratch,
          _scratchTransform,
        );
      }
    } finally {
      batch.clear();
      if (_scrollableRectCache.isNotEmpty) _scrollableRectCache.clear();
      if (_windowBoundsCache.isNotEmpty) _windowBoundsCache.clear();
      if (_ancestorTransformCache.isNotEmpty) _ancestorTransformCache.clear();
      if (_ancestorClipCache.isNotEmpty) _ancestorClipCache.clear();
      if (_clipTrailScratch.isNotEmpty) _clipTrailScratch.clear();
      if (_outerScrollableCache.isNotEmpty) _outerScrollableCache.clear();
    }
  }
}

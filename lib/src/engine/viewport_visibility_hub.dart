import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Callback invoked during a batched viewport visibility flush.
typedef ViewportMeasureCallback = void Function(
  Map<ScrollableState, Rect> scrollableRectCache,
  Map<FlutterView, Rect> windowBoundsCache,
);

/// Shared observer and post-frame batch hub for [WidgetsBinding] instances.
class ViewportVisibilityHub with WidgetsBindingObserver {
  /// Returns the shared [ViewportVisibilityHub] for the active binding.
  factory ViewportVisibilityHub() {
    final binding = WidgetsBinding.instance;
    return _hubs[binding] ??= ViewportVisibilityHub._(binding);
  }

  ViewportVisibilityHub._(this._binding);

  static final Expando<ViewportVisibilityHub> _hubs =
      Expando<ViewportVisibilityHub>();

  final WidgetsBinding _binding;
  final Set<VoidCallback> _metricsListeners = {};
  final Set<ViewportMeasureCallback> _pendingCallbacks = {};
  bool _observerAttached = false;
  bool _flushScheduled = false;

  /// Registers a listener notified when binding window metrics change.
  void addMetricsListener(VoidCallback listener) {
    if (_metricsListeners.add(listener) && !_observerAttached) {
      _binding.addObserver(this);
      _observerAttached = true;
    }
  }

  /// Unregisters a previously registered metrics listener.
  void removeMetricsListener(VoidCallback listener) {
    if (_metricsListeners.remove(listener) &&
        _metricsListeners.isEmpty &&
        _observerAttached) {
      _binding.removeObserver(this);
      _observerAttached = false;
    }
  }

  /// Enqueues [callback] to run once on the next post-frame flush.
  void scheduleFlush(ViewportMeasureCallback callback) {
    _pendingCallbacks.add(callback);
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _flush());
  }

  /// Cancels any pending measurement for [callback] before the next flush.
  void cancelFlush(ViewportMeasureCallback callback) {
    _pendingCallbacks.remove(callback);
  }

  @override
  void didChangeMetrics() {
    for (final listener in List<VoidCallback>.of(_metricsListeners)) {
      listener();
    }
  }

  void _flush() {
    _flushScheduled = false;
    if (_pendingCallbacks.isEmpty) return;
    final callbacks = List<ViewportMeasureCallback>.of(_pendingCallbacks);
    _pendingCallbacks.clear();
    final scrollableRectCache = <ScrollableState, Rect>{};
    final windowBoundsCache = <FlutterView, Rect>{};
    for (final callback in callbacks) {
      callback(scrollableRectCache, windowBoundsCache);
    }
  }
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:focus_on_it/src/models/focus_app_lifecycle_callbacks.dart';

/// Signature returning the current lifecycle callbacks for a subscriber.
typedef LifecycleCallbacksProvider = FocusAppLifecycleCallbacks? Function();

/// Cached result of scanning ancestor widgets for route offstage and hidden
/// ancestor containers (`IndexedStack` / `Offstage`) within the current frame.
typedef AncestorScanResult = ({
  bool hasHiddenAncestor,
  RenderOffstage? modalRouteOffstage,
});

/// Direct allocation-free client interface for [SharedLifecycleHub].
abstract interface class SharedLifecycleClient {
  /// Called when app foreground state changes.
  void onForegroundChanged(bool isInForeground);

  /// Current app lifecycle callbacks, if any.
  FocusAppLifecycleCallbacks? get lifecycleCallbacks;

  /// Called once during the post-frame route synchronization flush.
  void onRouteSyncFlush();

  /// Called when a watched ancestor `RenderOffstage` or `RenderIndexedStack`
  /// changes visibility state or detaches.
  void onAncestorVisibilityChanged();
}

typedef _Subscriber = ({
  ValueChanged<bool> onForegroundChanged,
  LifecycleCallbacksProvider getCallbacks,
});

class _OffstageWatchEntry {
  _OffstageWatchEntry(this.offstage) : lastValue = offstage.offstage;

  final RenderOffstage offstage;
  bool lastValue;
  final Set<SharedLifecycleClient> clients = {};
}

class _IndexedStackWatchEntry {
  _IndexedStackWatchEntry(this.stack) : lastIndex = stack.index;

  final RenderIndexedStack stack;
  int? lastIndex;
  final Set<SharedLifecycleClient> clients = {};
}

/// Shared [AppLifecycleListener] hub per [WidgetsBinding] to avoid allocating
/// one platform listener per `FocusOnIt` widget.
class SharedLifecycleHub {
  /// Returns the shared [SharedLifecycleHub] instance for [binding].
  factory SharedLifecycleHub(WidgetsBinding binding) {
    if (identical(binding, _lastBinding)) {
      return _lastHub;
    }
    final hub = _hubs[binding] ??= SharedLifecycleHub._(binding);
    _lastBinding = binding;
    _lastHub = hub;
    return hub;
  }

  SharedLifecycleHub._(this._binding) {
    _lastState = _binding.lifecycleState;
    _isInForeground = _isForegroundState(_lastState);
    _flushRouteSyncCallback = _flushRouteSyncs;
  }

  static final Expando<SharedLifecycleHub> _hubs =
      Expando<SharedLifecycleHub>();
  static WidgetsBinding? _lastBinding;
  static late SharedLifecycleHub _lastHub;

  final WidgetsBinding _binding;
  final Map<Object, _Subscriber> _subscribers = {};
  final Set<SharedLifecycleClient> _clients = {};
  final Set<VoidCallback> _pendingRouteSyncs = {};
  final Set<VoidCallback> _ancestorWatchers = {};
  final Map<Element, AncestorScanResult> _ancestorScanCache = {};
  final List<Element> _scanScratchElements = [];
  final Map<RenderOffstage, _OffstageWatchEntry> _offstageWatchesByNode = {};
  final List<_OffstageWatchEntry> _offstageWatches = [];
  final Map<RenderIndexedStack, _IndexedStackWatchEntry>
      _indexedStackWatchesByNode = {};
  final List<_IndexedStackWatchEntry> _indexedStackWatches = [];

  List<SharedLifecycleClient> _pendingClients = [];
  List<SharedLifecycleClient> _flushingClients = [];
  late final void Function(Duration) _flushRouteSyncCallback;

  AppLifecycleListener? _listener;
  AppLifecycleState? _lastState;
  late bool _isInForeground;
  bool _routeSyncFlushScheduled = false;
  bool _persistentFrameCallbackRegistered = false;

  /// Whether the application is currently considered in the foreground.
  bool get isInForeground => _isInForeground;

  /// Scans ancestors of [start] using a per-frame cache shared across
  /// sibling elements mounted or updated in the same frame.
  AncestorScanResult scanAncestors(Element start) {
    final cachedDirect = _ancestorScanCache[start];
    if (cachedDirect != null) return cachedDirect;

    var baseHasHidden = false;
    RenderOffstage? baseModalOffstage;
    final trail = _scanScratchElements..clear();

    start.visitAncestorElements((element) {
      final cached = _ancestorScanCache[element];
      if (cached != null) {
        baseHasHidden = cached.hasHiddenAncestor;
        baseModalOffstage = cached.modalRouteOffstage;
        return false;
      }
      trail.add(element);
      return true;
    });

    var hasHidden = baseHasHidden;
    var modalOffstage = baseModalOffstage;
    Widget? childWidget;

    for (var i = trail.length - 1; i >= 0; i--) {
      final element = trail[i];
      final widget = element.widget;
      if (i > 0) {
        childWidget = trail[i - 1].widget;
      } else {
        childWidget = start.widget;
      }
      if (widget is Offstage && childWidget is PageStorage) {
        final renderObject = element.renderObject;
        if (renderObject is RenderOffstage) {
          modalOffstage = renderObject;
        }
      } else if (widget is IndexedStack || widget is Offstage) {
        hasHidden = true;
      }
      _ancestorScanCache[element] = (
        hasHiddenAncestor: hasHidden,
        modalRouteOffstage: modalOffstage,
      );
    }
    trail.clear();

    return (
      hasHiddenAncestor: hasHidden,
      modalRouteOffstage: modalOffstage,
    );
  }

  /// Registers [callback] to be scheduled on frame updates while watching
  /// ancestors such as `IndexedStack` or `Offstage`.
  void addAncestorWatcher(VoidCallback callback) {
    _ancestorWatchers.add(callback);
    _ensurePersistentFrameCallback();
  }

  /// Unregisters an ancestor visibility [callback].
  void removeAncestorWatcher(VoidCallback callback) {
    _ancestorWatchers.remove(callback);
  }

  /// Watches [offstage] for [client], deduplicating frame checks per unique
  /// [RenderOffstage] node.
  void watchOffstage(RenderOffstage offstage, SharedLifecycleClient client) {
    var entry = _offstageWatchesByNode[offstage];
    if (entry == null) {
      entry = _OffstageWatchEntry(offstage);
      _offstageWatchesByNode[offstage] = entry;
      _offstageWatches.add(entry);
    }
    entry.clients.add(client);
    _ensurePersistentFrameCallback();
  }

  /// Stops watching [offstage] for [client].
  void unwatchOffstage(RenderOffstage offstage, SharedLifecycleClient client) {
    final entry = _offstageWatchesByNode[offstage];
    if (entry == null) return;
    entry.clients.remove(client);
    if (entry.clients.isEmpty) {
      _offstageWatchesByNode.remove(offstage);
      _removeFromList(_offstageWatches, entry);
    }
  }

  /// Watches [stack] for [client], deduplicating frame checks per unique
  /// [RenderIndexedStack] node.
  void watchIndexedStack(
    RenderIndexedStack stack,
    SharedLifecycleClient client,
  ) {
    var entry = _indexedStackWatchesByNode[stack];
    if (entry == null) {
      entry = _IndexedStackWatchEntry(stack);
      _indexedStackWatchesByNode[stack] = entry;
      _indexedStackWatches.add(entry);
    }
    entry.clients.add(client);
    _ensurePersistentFrameCallback();
  }

  /// Stops watching [stack] for [client].
  void unwatchIndexedStack(
    RenderIndexedStack stack,
    SharedLifecycleClient client,
  ) {
    final entry = _indexedStackWatchesByNode[stack];
    if (entry == null) return;
    entry.clients.remove(client);
    if (entry.clients.isEmpty) {
      _indexedStackWatchesByNode.remove(stack);
      _removeFromList(_indexedStackWatches, entry);
    }
  }

  /// Enqueues [client] to run once in the batched post-frame route sync.
  void scheduleClientRouteSync(SharedLifecycleClient client) {
    _pendingClients.add(client);
    _schedulePostFrameFlush();
  }

  /// Enqueues [callback] to run once in the batched post-frame route sync.
  void scheduleRouteSync(VoidCallback callback) {
    _pendingRouteSyncs.add(callback);
    _schedulePostFrameFlush();
  }

  /// Cancels a previously queued route sync [callback].
  void cancelRouteSync(VoidCallback callback) {
    _pendingRouteSyncs.remove(callback);
  }

  /// Registers a lightweight direct [client].
  void subscribeClient(SharedLifecycleClient client) {
    _ensureListener();
    _clients.add(client);
  }

  /// Removes a lightweight direct [client] and disposes listener when idle.
  void unsubscribeClient(SharedLifecycleClient client) {
    _clients.remove(client);
    _disposeListenerIfIdle();
  }

  /// Registers a subscriber keyed by [token].
  void subscribe(
    Object token, {
    required ValueChanged<bool> onForegroundChanged,
    required LifecycleCallbacksProvider getCallbacks,
  }) {
    _ensureListener();
    _subscribers[token] = (
      onForegroundChanged: onForegroundChanged,
      getCallbacks: getCallbacks,
    );
  }

  /// Removes the subscriber identified by [token] and disposes when empty.
  void unsubscribe(Object token) {
    _subscribers.remove(token);
    _disposeListenerIfIdle();
  }

  void _disposeListenerIfIdle() {
    if (_subscribers.isEmpty && _clients.isEmpty) {
      _pendingRouteSyncs.clear();
      _pendingClients.clear();
      _ancestorWatchers.clear();
      _offstageWatchesByNode.clear();
      _offstageWatches.clear();
      _indexedStackWatchesByNode.clear();
      _indexedStackWatches.clear();
      _ancestorScanCache.clear();
      _listener?.dispose();
      _listener = null;
    }
  }

  void _ensurePersistentFrameCallback() {
    if (_persistentFrameCallbackRegistered) return;
    _persistentFrameCallbackRegistered = true;
    _binding.addPersistentFrameCallback(_handlePersistentFrame);
  }

  void _schedulePostFrameFlush() {
    if (_routeSyncFlushScheduled) return;
    _routeSyncFlushScheduled = true;
    _binding.addPostFrameCallback(_flushRouteSyncCallback);
  }

  void _ensureListener() {
    if (_listener != null) return;
    _lastState = _binding.lifecycleState;
    _isInForeground = _isForegroundState(_lastState);
    _listener = AppLifecycleListener(
      binding: _binding,
      onResume: () => _setForeground(isInForeground: true),
      onPause: () => _setForeground(isInForeground: false),
      onHide: () {
        _setForeground(isInForeground: false);
        _dispatchCallbacks((callbacks) => callbacks.onHide?.call());
      },
      onShow: () => _dispatchCallbacks((callbacks) => callbacks.onShow?.call()),
      onInactive: () =>
          _dispatchCallbacks((callbacks) => callbacks.onInactive?.call()),
      onRestart: () =>
          _dispatchCallbacks((callbacks) => callbacks.onRestart?.call()),
      onDetach: () {
        _setForeground(isInForeground: false);
        _dispatchCallbacks((callbacks) => callbacks.onDetach?.call());
      },
      onStateChange: (state) {
        final oldState = _lastState;
        _lastState = state;
        _dispatchCallbacks(
          (callbacks) => callbacks.onStateChange?.call(oldState, state),
        );
      },
    );
  }

  void _handlePersistentFrame(Duration _) {
    for (var i = _offstageWatches.length - 1; i >= 0; i--) {
      final entry = _offstageWatches[i];
      final attached = entry.offstage.attached;
      final current = attached && entry.offstage.offstage;
      if (!attached || current != entry.lastValue) {
        entry.lastValue = current;
        _notifyClientsAncestorChanged(entry.clients);
      }
    }
    for (var i = _indexedStackWatches.length - 1; i >= 0; i--) {
      final entry = _indexedStackWatches[i];
      final attached = entry.stack.attached;
      final current = attached ? entry.stack.index : null;
      if (!attached || current != entry.lastIndex) {
        entry.lastIndex = current;
        _notifyClientsAncestorChanged(entry.clients);
      }
    }
    if (_ancestorWatchers.isNotEmpty) {
      for (final callback in List<VoidCallback>.of(_ancestorWatchers)) {
        callback();
      }
    }
  }

  static void _notifyClientsAncestorChanged(
    Set<SharedLifecycleClient> clients,
  ) {
    for (final client in clients) {
      client.onAncestorVisibilityChanged();
    }
  }

  void _flushRouteSyncs(Duration _) {
    _routeSyncFlushScheduled = false;
    if (_ancestorScanCache.isNotEmpty) {
      _ancestorScanCache.clear();
    }
    if (_pendingClients.isNotEmpty) {
      final batch = _pendingClients;
      _pendingClients = _flushingClients;
      _flushingClients = batch;
      try {
        for (var i = 0; i < batch.length; i++) {
          batch[i].onRouteSyncFlush();
        }
      } finally {
        batch.clear();
      }
    }
    if (_pendingRouteSyncs.isNotEmpty) {
      final callbacks = List<VoidCallback>.of(_pendingRouteSyncs);
      _pendingRouteSyncs.clear();
      for (final callback in callbacks) {
        callback();
      }
    }
  }

  void _setForeground({required bool isInForeground}) {
    if (_isInForeground == isInForeground) return;
    _isInForeground = isInForeground;
    if (_clients.isNotEmpty) {
      for (final client in List<SharedLifecycleClient>.of(_clients)) {
        if (_clients.contains(client)) {
          client.onForegroundChanged(isInForeground);
        }
      }
    }
    if (_subscribers.isNotEmpty) {
      for (final token in List<Object>.of(_subscribers.keys)) {
        _subscribers[token]?.onForegroundChanged(isInForeground);
      }
    }
  }

  void _dispatchCallbacks(
    void Function(FocusAppLifecycleCallbacks callbacks) action,
  ) {
    if (_clients.isNotEmpty) {
      for (final client in List<SharedLifecycleClient>.of(_clients)) {
        if (_clients.contains(client)) {
          final callbacks = client.lifecycleCallbacks;
          if (callbacks != null) {
            action(callbacks);
          }
        }
      }
    }
    if (_subscribers.isNotEmpty) {
      for (final token in List<Object>.of(_subscribers.keys)) {
        final callbacks = _subscribers[token]?.getCallbacks();
        if (callbacks != null) {
          action(callbacks);
        }
      }
    }
  }

  static void _removeFromList<T>(List<T> list, T target) {
    final index = list.indexOf(target);
    if (index < 0) return;
    final last = list.removeLast();
    if (index < list.length) {
      list[index] = last;
    }
  }

  static bool _isForegroundState(AppLifecycleState? state) {
    return switch (state) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        false,
      AppLifecycleState.resumed || AppLifecycleState.inactive || null => true,
    };
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:focus_on_it/src/models/focus_state.dart';

/// Deterministic state machine combining foreground, route, and viewport state.
class FocusStateMachine {
  /// Creates a [FocusStateMachine].
  FocusStateMachine({
    required bool useViewport,
    bool initialForeground = true,
    bool triggerOnInit = true,
    Duration minFocusDuration = Duration.zero,
    bool applyDwellOnResume = false,
    bool notifyOnDispose = false,
    VoidCallback? onFocus,
    VoidCallback? onUnfocus,
    VoidCallback? onVisibilityGained,
    VoidCallback? onVisibilityLost,
    VoidCallback? onForegroundGained,
    VoidCallback? onForegroundLost,
    ValueChanged<FocusState>? onStateChanged,
  })  : _useViewport = useViewport,
        _isInForeground = initialForeground,
        _triggerOnInit = triggerOnInit,
        _minFocusDuration = minFocusDuration,
        _applyDwellOnResume = applyDwellOnResume,
        _notifyOnDispose = notifyOnDispose,
        _isViewportVisible = !useViewport,
        _hasViewportMeasurement = !useViewport,
        _onFocus = onFocus,
        _onUnfocus = onUnfocus,
        _onVisibilityGained = onVisibilityGained,
        _onVisibilityLost = onVisibilityLost,
        _onForegroundGained = onForegroundGained,
        _onForegroundLost = onForegroundLost,
        _onStateChanged = onStateChanged,
        _state = FocusState(
          isFocused: false,
          isVisible: false,
          isInForeground: initialForeground,
        );

  bool _useViewport;
  bool _isInForeground;
  final bool _triggerOnInit;
  Duration _minFocusDuration;
  bool _applyDwellOnResume;
  bool _notifyOnDispose;

  bool _isRouteActive = false;
  bool _isViewportVisible;
  bool _hasRouteMeasurement = false;
  bool _hasViewportMeasurement;
  double _visibleFraction = 0;

  bool _isFocused = false;
  bool _isVisibleConfirmed = false;
  bool _hasInitialized = false;
  bool _disposed = false;
  Timer? _dwellTimer;
  bool _dwellFromForeground = false;

  VoidCallback? _onFocus;
  VoidCallback? _onUnfocus;
  VoidCallback? _onVisibilityGained;
  VoidCallback? _onVisibilityLost;
  VoidCallback? _onForegroundGained;
  VoidCallback? _onForegroundLost;
  ValueChanged<FocusState>? _onStateChanged;

  FocusState _state;

  /// The current immutable [FocusState] snapshot.
  FocusState get state => _state;

  /// Whether the widget currently has confirmed focus.
  bool get isFocused => _isFocused;

  /// Whether the widget is currently confirmed visible.
  bool get isVisible => _isVisibleConfirmed;

  bool get _rawVisible => _isRouteActive && _isViewportVisible;

  double get _effectiveFraction {
    if (!_rawVisible) return 0;
    return _useViewport ? _visibleFraction : 1;
  }

  /// Updates whether the enclosing route/subtree is currently active.
  void updateRouteActive({required bool isRouteActive}) {
    if (_disposed) return;
    _hasRouteMeasurement = true;
    _isRouteActive = isRouteActive;
    _evaluateVisibility();
  }

  /// Updates viewport visibility status and fraction in `[0.0, 1.0]`.
  void updateViewport({
    required bool isViewportVisible,
    required double visibleFraction,
  }) {
    if (_disposed) return;
    _hasViewportMeasurement = true;
    _isViewportVisible = isViewportVisible;
    _visibleFraction = visibleFraction.clamp(0.0, 1.0);
    _evaluateVisibility();
  }

  /// Updates whether the application is currently in the foreground.
  void updateForeground({required bool isInForeground}) {
    if (_disposed || _isInForeground == isInForeground) return;
    _isInForeground = isInForeground;

    if (!isInForeground) {
      _cancelDwellTimer();
      final wasFocused = _isFocused;
      _isFocused = false;
      _isVisibleConfirmed = _rawVisible;
      _syncState(
        isFocused: false,
        isVisible: _isVisibleConfirmed,
        isInForeground: false,
        visibleFraction: _effectiveFraction,
      );
      if (wasFocused) {
        _onUnfocus?.call();
        _onForegroundLost?.call();
      }
      return;
    }

    if (_rawVisible) {
      if (!_hasInitialized && !_triggerOnInit) {
        _hasInitialized = true;
        _isFocused = true;
        _isVisibleConfirmed = true;
        _syncState(
          isFocused: true,
          isVisible: true,
          isInForeground: true,
          visibleFraction: _effectiveFraction,
        );
        return;
      }

      if (_applyDwellOnResume && _minFocusDuration > Duration.zero) {
        _scheduleDwellTimer(fromForeground: true);
        _syncState(
          isFocused: _isFocused,
          isVisible: _isVisibleConfirmed,
          isInForeground: true,
          visibleFraction: _effectiveFraction,
        );
      } else {
        _hasInitialized = true;
        _isFocused = true;
        _isVisibleConfirmed = true;
        _syncState(
          isFocused: true,
          isVisible: true,
          isInForeground: true,
          visibleFraction: _effectiveFraction,
        );
        _onFocus?.call();
        _onForegroundGained?.call();
      }
    } else {
      _syncState(
        isFocused: false,
        isVisible: false,
        isInForeground: true,
        visibleFraction: 0,
      );
    }
  }

  /// Replaces callback references, typically during `didUpdateWidget`.
  void updateCallbacks({
    VoidCallback? onFocus,
    VoidCallback? onUnfocus,
    VoidCallback? onVisibilityGained,
    VoidCallback? onVisibilityLost,
    VoidCallback? onForegroundGained,
    VoidCallback? onForegroundLost,
    ValueChanged<FocusState>? onStateChanged,
  }) {
    _onFocus = onFocus;
    _onUnfocus = onUnfocus;
    _onVisibilityGained = onVisibilityGained;
    _onVisibilityLost = onVisibilityLost;
    _onForegroundGained = onForegroundGained;
    _onForegroundLost = onForegroundLost;
    _onStateChanged = onStateChanged;
  }

  /// Updates configuration flags, typically during `didUpdateWidget`.
  void updateConfig({
    bool? useViewport,
    Duration? minFocusDuration,
    bool? applyDwellOnResume,
    bool? notifyOnDispose,
  }) {
    if (_disposed) return;

    var needsEvaluation = false;
    if (useViewport != null && useViewport != _useViewport) {
      _useViewport = useViewport;
      if (!useViewport) {
        _isViewportVisible = true;
        _visibleFraction = 1;
        _hasViewportMeasurement = true;
      } else {
        _isViewportVisible = false;
        _visibleFraction = 0;
        _hasViewportMeasurement = false;
      }
      needsEvaluation = true;
    }

    if (minFocusDuration != null && minFocusDuration != _minFocusDuration) {
      _minFocusDuration = minFocusDuration;
      if (_dwellTimer != null) {
        final fromForeground = _dwellFromForeground;
        _cancelDwellTimer();
        if (_isInForeground && _rawVisible && !_isFocused) {
          if (_minFocusDuration == Duration.zero) {
            _confirmFocus(fromForeground: fromForeground);
          } else {
            _scheduleDwellTimer(fromForeground: fromForeground);
          }
        }
      }
    }

    if (applyDwellOnResume != null &&
        applyDwellOnResume != _applyDwellOnResume) {
      _applyDwellOnResume = applyDwellOnResume;
      if (!applyDwellOnResume &&
          _dwellTimer != null &&
          _dwellFromForeground &&
          _isInForeground &&
          _rawVisible &&
          !_isFocused) {
        _cancelDwellTimer();
        _confirmFocus(fromForeground: true);
      }
    }

    if (notifyOnDispose != null) {
      _notifyOnDispose = notifyOnDispose;
    }

    if (needsEvaluation) {
      _evaluateVisibility();
    }
  }

  /// Disposes internal timers and optionally notifies unfocus on teardown.
  void dispose() {
    if (_disposed) return;
    _cancelDwellTimer();
    _disposed = true;

    if (_notifyOnDispose && _isFocused) {
      _isFocused = false;
      _isVisibleConfirmed = false;
      _syncState(
        isFocused: false,
        isVisible: false,
        isInForeground: _isInForeground,
        visibleFraction: 0,
      );
      _onUnfocus?.call();
      _onVisibilityLost?.call();
    }
  }

  void _evaluateVisibility() {
    final visible = _rawVisible;

    if (!_isInForeground) {
      _cancelDwellTimer();
      _isVisibleConfirmed = visible;
      _syncState(
        isFocused: false,
        isVisible: visible,
        isInForeground: false,
        visibleFraction: _effectiveFraction,
      );
      return;
    }

    if (visible && !_isFocused) {
      if (!_hasInitialized && !_triggerOnInit) {
        _hasInitialized = true;
        _isFocused = true;
        _isVisibleConfirmed = true;
        _syncState(
          isFocused: true,
          isVisible: true,
          isInForeground: true,
          visibleFraction: _effectiveFraction,
        );
        return;
      }

      if (_minFocusDuration > Duration.zero) {
        if (_dwellTimer == null) {
          _scheduleDwellTimer(fromForeground: false);
        }
        _syncState(
          isFocused: false,
          isVisible: _isVisibleConfirmed,
          isInForeground: true,
          visibleFraction: _effectiveFraction,
        );
        return;
      }

      _confirmFocus(fromForeground: false);
      return;
    }

    if (!visible) {
      _cancelDwellTimer();
      if (_isFocused) {
        _isFocused = false;
        _isVisibleConfirmed = false;
        _syncState(
          isFocused: false,
          isVisible: false,
          isInForeground: true,
          visibleFraction: 0,
        );
        _onUnfocus?.call();
        _onVisibilityLost?.call();
      } else {
        if (_hasRouteMeasurement && _hasViewportMeasurement) {
          _hasInitialized = true;
        }
        _isVisibleConfirmed = false;
        _syncState(
          isFocused: false,
          isVisible: false,
          isInForeground: true,
          visibleFraction: 0,
        );
      }
      return;
    }

    _syncState(
      isFocused: true,
      isVisible: true,
      isInForeground: true,
      visibleFraction: _effectiveFraction,
    );
  }

  void _scheduleDwellTimer({required bool fromForeground}) {
    _dwellFromForeground = fromForeground;
    _dwellTimer = Timer(_minFocusDuration, () {
      _dwellTimer = null;
      if (_disposed || !_isInForeground || !_rawVisible || _isFocused) {
        return;
      }
      _confirmFocus(fromForeground: _dwellFromForeground);
    });
  }

  void _confirmFocus({required bool fromForeground}) {
    _hasInitialized = true;
    _isFocused = true;
    _isVisibleConfirmed = true;
    _syncState(
      isFocused: true,
      isVisible: true,
      isInForeground: true,
      visibleFraction: _effectiveFraction,
    );
    _onFocus?.call();
    if (fromForeground) {
      _onForegroundGained?.call();
    } else {
      _onVisibilityGained?.call();
    }
  }

  void _cancelDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
  }

  void _syncState({
    required bool isFocused,
    required bool isVisible,
    required bool isInForeground,
    required double visibleFraction,
  }) {
    final current = _state;
    if (current.isFocused == isFocused &&
        current.isVisible == isVisible &&
        current.isInForeground == isInForeground &&
        current.visibleFraction == visibleFraction) {
      return;
    }
    final next = FocusState(
      isFocused: isFocused,
      isVisible: isVisible,
      isInForeground: isInForeground,
      visibleFraction: visibleFraction,
    );
    _state = next;
    _onStateChanged?.call(next);
  }
}

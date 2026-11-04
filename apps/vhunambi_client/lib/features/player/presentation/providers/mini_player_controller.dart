import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Threshold (ms) for hold gesture to activate Manual_Mode drag.
const int kHoldGestureThresholdMs = 350;

/// Velocity threshold (px/s) for horizontal fling dismiss.
const double kFlingDismissVelocityThreshold = 250.0;

/// Top extreme zone height (dp) — dragging here morphs to Pill_Form.
const double kTopExtremeZoneHeight = 72.0;

/// Bottom extreme zone height (dp) — dragging here returns to Bar + Auto_Mode.
const double kBottomExtremeZoneHeight = 120.0;

/// Direction classification lock distance (dp) — after this much travel,
/// the drag direction (vertical vs horizontal) is locked.
const double kDirectionLockDistance = 24.0;

/// Scale factor applied during hold gesture feedback.
const double kHoldGestureScale = 1.03;

/// Mini player form — Bar (docked above bottom nav) or Pill (minimal floating capsule).
enum PlayerForm { bar, pill }

/// Mini player positioning mode — Auto (obstacle avoidance) or Manual.
enum PlayerMode { auto, manual }

/// Persisted form/mode/position state.
@immutable
class PlayerFormState {
  final PlayerForm form;
  final PlayerMode mode;
  final Offset position;

  const PlayerFormState({
    required this.form,
    required this.mode,
    required this.position,
  });
}

/// State management for the Adaptive Mini Player.
///
/// Coordinates form (bar/card/pill), mode (auto/manual), screen position,
/// obstacle registry, and persistence. All state changes notify listeners
/// via ChangeNotifier so [MiniPlayerHost] can rebuild and animate.
class MiniPlayerController extends ChangeNotifier {
  static const String _keyForm = 'player_form';
  static const String _keyMode = 'player_mode';
  static const String _keyPosX = 'player_position_x';
  static const String _keyPosY = 'player_position_y';

  PlayerForm _form = PlayerForm.bar;
  PlayerMode _mode = PlayerMode.auto;
  Offset _position = Offset.zero;
  final Map<String, Rect> _obstacles = {};
  bool _isDragging = false;
  bool _isNowPlayingOpen = false;
  bool _isDisposed = false;

  /// Current player form.
  PlayerForm get form => _form;

  /// Current positioning mode.
  PlayerMode get mode => _mode;

  /// Current screen position.
  Offset get position => _position;

  /// Registered obstacles (page-declared UI to avoid in auto mode).
  Map<String, Rect> get obstacles => Map.unmodifiable(_obstacles);

  /// Whether a drag gesture is active.
  bool get isDragging => _isDragging;

  /// Whether Now Playing cockpit is open.
  bool get isNowPlayingOpen => _isNowPlayingOpen;

  /// Reserved bottom padding — bar height + 8dp when bar form + auto mode,
  /// otherwise 0 so content can use full screen.
  double get reservedBottom {
    if (_form != PlayerForm.bar) return 0;
    if (_mode == PlayerMode.manual) return 0;
    return 90.0 + 8.0; // bar height + 8dp padding
  }

  MiniPlayerController() {
    loadState();
  }

  /// Sets the player form and persists. Notifies listeners so [MiniPlayerHost]
  /// can animate the morph.
  void setForm(PlayerForm form) {
    if (_isDisposed || _form == form) return;
    _form = form;
    _persistState();
    notifyListeners();
  }

  /// Sets the player mode and persists.
  void setMode(PlayerMode mode) {
    if (_isDisposed || _mode == mode) return;
    _mode = mode;
    _persistState();
    notifyListeners();
  }

  /// Sets drag state.
  void setDragging(bool dragging) {
    if (_isDisposed || _isDragging == dragging) return;
    _isDragging = dragging;
    notifyListeners();
  }

  /// Sets Now Playing open state.
  void setNowPlayingOpen(bool open) {
    if (_isDisposed || _isNowPlayingOpen == open) return;
    _isNowPlayingOpen = open;
    notifyListeners();
  }

  /// Registers a page-declared obstacle rectangle by ID.
  void registerObstacle(String id, Rect rect) {
    if (_isDisposed) return;
    _obstacles[id] = rect;
    _recalculateAutoPosition();
    notifyListeners();
  }

  /// Unregisters an obstacle by ID.
  void unregisterObstacle(String id) {
    if (_isDisposed) return;
    _obstacles.remove(id);
    _recalculateAutoPosition();
    notifyListeners();
  }

  /// Recalculates auto position to avoid registered obstacles.
  /// [screenSize] is used to position the bar above bottom navigation.
  void _recalculateAutoPosition([Size? screenSize]) {
    if (_mode != PlayerMode.auto || _form != PlayerForm.bar) return;
    if (screenSize != null) {
      double targetY = screenSize.height - 128.0;

      // Inspect registered obstacles intersecting bottom dock zone
      final dockObstacles = _obstacles.values.where(
        (rect) => rect.bottom > screenSize.height - 240,
      );
      if (dockObstacles.isNotEmpty) {
        final highestTop = dockObstacles.map((o) => o.top).reduce((a, b) => a < b ? a : b);
        targetY = (highestTop - 64.0 - 8.0).clamp(8.0, targetY);
      }

      _position = Offset(8.0, targetY);
    }
  }

  /// Clamps manual drag position to safe screen boundaries.
  Offset clampedPosition(Size screenSize, double bottomSafeArea, [double topSafeArea = 0.0]) {
    final double formWidth = switch (_form) {
      PlayerForm.bar => screenSize.width - 16.0,
      PlayerForm.pill => 160.0,
    };
    final double formHeight = switch (_form) {
      PlayerForm.bar => 64.0,
      PlayerForm.pill => 48.0,
    };

    const minX = 8.0;
    final maxX = (screenSize.width - formWidth - 8.0).clamp(minX, double.infinity);
    final minY = topSafeArea + 8.0;
    final bottomDockHeight = 56.0 + bottomSafeArea;
    final maxY = (screenSize.height - formHeight - bottomDockHeight - 12.0).clamp(minY, double.infinity);

    return Offset(
      _position.dx.clamp(minX, maxX),
      _position.dy.clamp(minY, maxY),
    );
  }

  /// Calculates target position for auto mode given screen geometry and registered obstacles.
  Offset calculateAutoPosition({
    required Size screenSize,
    required double bottomSafeArea,
  }) {
    if (_mode == PlayerMode.manual) {
      return clampedPosition(screenSize, bottomSafeArea);
    }

    switch (_form) {
      case PlayerForm.bar:
        // Base docked position: 8dp above bottom navigation bar (56dp + bottomSafeArea)
        final defaultDockBottom = 56.0 + bottomSafeArea + 8.0;
        double targetY = screenSize.height - defaultDockBottom - 64.0;

        // Obstacle avoidance: if any registered obstacle intersects the bottom area
        final dockObstacles = _obstacles.values.where(
          (rect) => rect.bottom > screenSize.height - 240,
        );
        if (dockObstacles.isNotEmpty) {
          final highestTop = dockObstacles.map((o) => o.top).reduce((a, b) => a < b ? a : b);
          targetY = min(targetY, highestTop - 64.0 - 8.0).clamp(8.0, targetY);
        }

        return Offset(8.0, targetY);

      case PlayerForm.pill:
        // Floating pill docked cleanly 12dp above the bottom navigation dock
        return Offset(
          screenSize.width - 160.0 - 16.0,
          screenSize.height - (56.0 + bottomSafeArea + 12.0 + 48.0),
        );
    }
  }

  /// Starts a drag at [globalPosition].
  void startDrag(Offset globalPosition) {
    _mode = PlayerMode.manual;
    _position = globalPosition;
    _isDragging = true;
    notifyListeners();
  }

  /// Updates drag position to [globalPosition].
  void updateDrag(Offset globalPosition) {
    _position = globalPosition;
    notifyListeners();
  }

  /// Resets the mini player to the docked Bar in auto mode.
  void resetToDock([Size? screenSize]) {
    if (_isDisposed) return;
    _form = PlayerForm.bar;
    _mode = PlayerMode.auto;
    _isDragging = false;
    _recalculateAutoPosition(screenSize);
    _persistState();
    notifyListeners();
  }

  /// Ends a drag with [velocity], applying extreme zone logic and bin dismiss check.
  /// Returns true if the player should be dismissed.
  bool endDrag(
    Offset velocity,
    Size screenSize, {
    bool dismissedInBin = false,
    double bottomSafeArea = 0.0,
  }) {
    _isDragging = false;

    if (dismissedInBin) {
      resetToDock(screenSize);
      return true;
    }

    // Fling dismiss: horizontal velocity > 250 px/s
    if (velocity.dx.abs() > kFlingDismissVelocityThreshold) {
      resetToDock(screenSize);
      return true; // Signal dismiss to MiniPlayerHost
    }

    // Bottom extreme zone: return to Bar + Auto_Mode
    final dockThreshold = screenSize.height - (56.0 + bottomSafeArea + 64.0 + 40.0);
    final bottomZone = _position.dy > dockThreshold;

    if (bottomZone) {
      // Bottom extreme zone: return to Bar + Auto_Mode
      _form = PlayerForm.bar;
      _mode = PlayerMode.auto;
      _recalculateAutoPosition(screenSize);
    } else {
      // Manual placement: morph to Pill_Form and snap to nearest horizontal edge
      _form = PlayerForm.pill;
      _mode = PlayerMode.manual;
      const formWidth = 160.0;
      const snapLeft = 16.0;
      final snapRight = screenSize.width - formWidth - 16.0;
      final targetX =
          (_position.dx + formWidth / 2 < screenSize.width / 2) ? snapLeft : snapRight;
      _position = Offset(targetX, _position.dy);
    }

    _persistState();
    notifyListeners();
    return false;
  }

  /// Loads persisted form/mode/position from SharedPreferences.
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formIndex = prefs.getInt(_keyForm) ?? 0;
      final modeIndex = prefs.getInt(_keyMode) ?? 0;
      final posX = prefs.getDouble(_keyPosX) ?? 0.0;
      final posY = prefs.getDouble(_keyPosY) ?? 0.0;

      // Safe migration: legacy formIndex 1 (card) or >= 2 (old pill) safely maps to pill.
      _form = formIndex >= PlayerForm.values.length
          ? PlayerForm.pill
          : PlayerForm.values[formIndex.clamp(0, PlayerForm.values.length - 1)];
      _mode = PlayerMode.values[modeIndex.clamp(0, PlayerMode.values.length - 1)];
      _position = Offset(posX, posY);
    } catch (_) {
      // Use defaults on failure.
    }
    notifyListeners();
  }

  /// Persists current form/mode/position to SharedPreferences.
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyForm, _form.index);
      await prefs.setInt(_keyMode, _mode.index);
      await prefs.setDouble(_keyPosX, _position.dx);
      await prefs.setDouble(_keyPosY, _position.dy);
    } catch (_) {
      // Silently ignore persistence failures.
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

/// Riverpod provider for [MiniPlayerController].
final miniPlayerControllerProvider =
    ChangeNotifierProvider<MiniPlayerController>((ref) {
  return MiniPlayerController();
});

# Technical Design Document: Adaptive Mini Player & Now Playing Cockpit

## Overview

The Adaptive Mini Player is a comprehensive music player interface redesign that introduces three morphing player forms (Bar, Card, Pill) with intelligent auto-positioning, manual gesture control, and visual feedback through cover-art reactive glows. This feature transforms the current fixed docked player bar into a flexible, context-aware interface that adapts to user needs and screen content while addressing critical UX issues including permanent screen real estate consumption (~8% of screen height), blocked cockpit controls during music generation, and lack of dismissal or repositioning mechanisms.

### Core Capabilities

1. **Three Morphing Forms**: Bar (full-width dock), Card (128dp square), Pill (minimal with glow)
2. **Intelligent Positioning**: Auto-mode obstacle avoidance and manual drag-to-position
3. **Advanced Gestures**: Hold-drag morphing, extreme zone detection, dismiss-by-fling
4. **Visual Feedback**: Cover-art reactive glow driven by waveform amplitude
5. **Now Playing Fixes**: Material theming fixes, 12 functional controls, layout improvements

### Design Goals

- **Zero Screen Intrusion**: Player adapts to content, not vice versa
- **Gestural Mastery**: Single-gesture repositioning and form morphing
- **Performance First**: 60fps animations on mid-range Android (Snapdragon 662)
- **Accessibility**: Semantic actions for gesture alternatives
- **State Persistence**: User preferences survive sessions and device rotation

## Architecture

### System Architecture

```
MaterialApp
└── MaterialApp.builder
    └── Stack
        ├── Original child (all routes)
        └── MiniPlayerHost ← New global overlay
            ├── Material(type: transparency) ← Prevents yellow underlines
            └── Positioned/AnimatedPositioned
                └── PlayerFormWidget
                    ├── BarForm (MobileMiniPlayer + controls)
                    ├── CardForm (128dp square + progress %)
                    └── PillForm (minimal + glow effect)
```

### Component Hierarchy

```mermaid
graph TB
    A[MaterialApp.builder] --> B[Stack]
    B --> C[MiniPlayerHost]
    B --> D[App Routes]
    C --> E[Material Wrapper]
    E --> F{Form Router}
    F --> G[BarForm]
    F --> H[CardForm]
    F --> I[PillForm]
    C --> J[GestureRecognitionLayer]
    J --> K[LongPressRecognizer]
    J --> L[DragRecognizer]
    J --> M[FlingRecognizer]
    C --> N[MiniPlayerController]
    N --> O[ObstacleRegistry]
    N --> P[PositionManager]
    N --> Q[PersistenceService]
```

### Navigation Flow

```mermaid
stateDiagram-v2
    [*] --> BarDocked: New track
    BarDocked --> ManualBarPosition: Hold + Vertical Drag
    BarDocked --> CardLeft: Hold + Diagonal ↖
    BarDocked --> CardRight: Hold + Diagonal ↗
    ManualBarPosition --> BarDocked: Release in Bottom Zone
    CardLeft --> PillTop: Drag to Top Zone
    CardRight --> PillTop: Drag to Top Zone
    PillTop --> CardLeft: Hold + Drag
    PillTop --> BarDocked: Drag to Bottom Zone
    CardLeft --> BarDocked: Drag to Bottom Zone
    CardRight --> BarDocked: Drag to Bottom Zone
    
    BarDocked --> [*]: Horizontal Fling
    ManualBarPosition --> [*]: Horizontal Fling
    CardLeft --> [*]: Horizontal Fling
    CardRight --> [*]: Horizontal Fling
    PillTop --> [*]: Horizontal Fling
    
    BarDocked --> NowPlaying: Tap
    ManualBarPosition --> NowPlaying: Tap
    CardLeft --> NowPlaying: Tap
    CardRight --> NowPlaying: Tap
    PillTop --> NowPlaying: Tap
    NowPlaying --> BarDocked: Back/Dismiss (restores form)
```

## Components and Interfaces

### 1. MiniPlayerHost

**Purpose**: Global widget managing player lifecycle, rendering, and Now Playing modal coordination.

**Location**: `lib/features/player/presentation/widgets/mini_player_host.dart`

**Interface**:
```dart
class MiniPlayerHost extends ConsumerStatefulWidget {
  const MiniPlayerHost({super.key});
  
  @override
  ConsumerState<MiniPlayerHost> createState() => _MiniPlayerHostState();
}

class _MiniPlayerHostState extends ConsumerState<MiniPlayerHost> 
    with TickerProviderStateMixin {
  
  late AnimationController _morphController;
  late AnimationController _positionController;
  late AnimationController _dismissController;
  
  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(miniPlayerControllerProvider);
    final playerState = ref.watch(playerStateProvider);
    
    // Hide during onboarding, splash, auth, or Now Playing
    if (_shouldHide(context, controller)) {
      return const SizedBox.shrink();
    }
    
    // Hide when no active track
    if (!playerState.hasActiveTrack) {
      return const SizedBox.shrink();
    }
    
    // Hide when keyboard is open
    final viewInsets = MediaQuery.of(context).viewInsets;
    if (viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Extreme zone highlights
          if (controller.isDragging) ...[
            _buildExtremeZoneHighlight(context, controller),
          ],
          
          // Player form widget
          AnimatedPositioned(
            duration: _positionController.duration!,
            curve: Curves.easeOutCubic,
            left: controller.position.dx,
            top: controller.position.dy,
            child: GestureDetector(
              onLongPressStart: _handleLongPressStart,
              onLongPressMoveUpdate: _handleDragUpdate,
              onLongPressEnd: _handleDragEnd,
              child: AnimatedBuilder(
                animation: _morphController,
                builder: (context, child) {
                  return _buildPlayerForm(context, controller);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  bool _shouldHide(BuildContext context, MiniPlayerController controller) {
    final route = ModalRoute.of(context);
    if (route == null) return true;
    
    // Check route names
    final routeName = route.settings.name;
    return routeName == '/onboarding' ||
           routeName == '/splash' ||
           routeName == '/auth' ||
           controller.isNowPlayingOpen;
  }
  
  Widget _buildPlayerForm(BuildContext context, MiniPlayerController controller) {
    switch (controller.form) {
      case PlayerForm.bar:
        return _buildBarForm(context);
      case PlayerForm.card:
        return _buildCardForm(context);
      case PlayerForm.pill:
        return _buildPillForm(context);
    }
  }
  
  void _handleLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    ref.read(miniPlayerControllerProvider.notifier).startDrag(details.globalPosition);
  }
  
  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    ref.read(miniPlayerControllerProvider.notifier).updateDrag(details.globalPosition);
  }
  
  void _handleDragEnd(LongPressEndDetails details) {
    ref.read(miniPlayerControllerProvider.notifier).endDrag(details.velocity);
  }
  
  @override
  void dispose() {
    _morphController.dispose();
    _positionController.dispose();
    _dismissController.dispose();
    super.dispose();
  }
}
```

**Installation Point**:
```dart
// lib/main.dart
class VhunambiApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // ... other config
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const MiniPlayerHost(), // ← Global overlay
          ],
        );
      },
    );
  }
}
```

**Responsibilities**:
- Mount above all routes via `MaterialApp.builder`
- Wrap in `Material(type: MaterialType.transparency)` to prevent yellow underlines
- Watch `playerStateProvider` for active track state
- Render current player form or hide if inactive
- Manage Now Playing cockpit modal state
- Coordinate animation controllers for morph, position, and dismiss
- Handle lifecycle hiding (onboarding, splash, auth, Now Playing, keyboard)

---

### 2. MiniPlayerController

**Purpose**: State management coordinating form, mode, position, and obstacle avoidance.

**Location**: `lib/features/player/presentation/providers/mini_player_controller.dart`

**Interface**:
```dart
enum PlayerForm { bar, card, pill }
enum PlayerMode { auto, manual }

class MiniPlayerController extends ChangeNotifier {
  PlayerForm _form = PlayerForm.bar;
  PlayerMode _mode = PlayerMode.auto;
  Offset _position = Offset.zero;
  final Map<String, Rect> _obstacles = {};
  
  bool _isDragging = false;
  Offset? _dragStartPosition;
  DragDirection? _dragDirection;
  bool _isNowPlayingOpen = false;
  
  // Color palette from current track's cover art
  List<Color> _glowColors = [];
  
  // Getters
  PlayerForm get form => _form;
  PlayerMode get mode => _mode;
  Offset get position => _position;
  bool get isDragging => _isDragging;
  bool get isNowPlayingOpen => _isNowPlayingOpen;
  List<Color> get glowColors => _glowColors;
  
  double get reservedBottom {
    if (_form != PlayerForm.bar) return 0;
    if (_mode == PlayerMode.manual) return 0;
    // Return bar height + 8dp padding
    return 72.0; // 64dp bar + 8dp padding
  }
  
  // Obstacle management
  void registerObstacle(String id, Rect rect) {
    _obstacles[id] = rect;
    if (_mode == PlayerMode.auto && _form == PlayerForm.bar) {
      _recalculateAutoPosition();
    }
    notifyListeners();
  }
  
  void unregisterObstacle(String id) {
    _obstacles.remove(id);
    if (_mode == PlayerMode.auto && _form == PlayerForm.bar) {
      _recalculateAutoPosition();
    }
    notifyListeners();
  }
  
  // Drag gesture handling
  void startDrag(Offset globalPosition) {
    _isDragging = true;
    _dragStartPosition = globalPosition;
    _dragDirection = null;
    notifyListeners();
  }
  
  void updateDrag(Offset globalPosition) {
    if (!_isDragging || _dragStartPosition == null) return;
    
    final delta = globalPosition - _dragStartPosition!;
    
    // Classify direction after 24dp travel
    if (_dragDirection == null && delta.distance >= 24) {
      _dragDirection = _classifyDirection(delta);
      if (_dragDirection == DragDirection.ignored) {
        // Cancel drag if angle too shallow
        _isDragging = false;
        notifyListeners();
        return;
      }
    }
    
    // Update position based on direction
    if (_dragDirection != null) {
      _updatePositionForDrag(globalPosition, _dragDirection!);
    }
    
    notifyListeners();
  }
  
  void endDrag(Velocity velocity) {
    if (!_isDragging) return;
    
    // Check for fling dismiss (horizontal velocity > 250 px/s)
    final horizontalVelocity = velocity.pixelsPerSecond.dx.abs();
    if (horizontalVelocity > 250) {
      _handleDismiss();
      return;
    }
    
    // Check extreme zones
    if (_isInBottomExtremeZone()) {
      _morphToBarAndDock();
    } else if (_isInTopExtremeZone()) {
      _morphToPill();
    } else {
      // Stay in manual mode at current position
      _mode = PlayerMode.manual;
      _persistState();
    }
    
    _isDragging = false;
    _dragStartPosition = null;
    _dragDirection = null;
    notifyListeners();
  }
  
  // Form morphing
  void setForm(PlayerForm form) {
    _form = form;
    _persistState();
    notifyListeners();
  }
  
  void setMode(PlayerMode mode) {
    _mode = mode;
    if (mode == PlayerMode.auto && _form == PlayerForm.bar) {
      _recalculateAutoPosition();
    }
    _persistState();
    notifyListeners();
  }
  
  void setPosition(Offset position) {
    _position = position;
    _persistState();
    notifyListeners();
  }
  
  // Auto mode positioning
  void _recalculateAutoPosition() {
    if (_mode != PlayerMode.auto || _form != PlayerForm.bar) return;
    
    // Find highest obstacle in dock area
    final dockRect = _getDockRect();
    double highestY = dockRect.top;
    
    for (final obstacle in _obstacles.values) {
      if (obstacle.overlaps(dockRect)) {
        highestY = min(highestY, obstacle.top - 8.0);
      }
    }
    
    _position = Offset(0, highestY);
    notifyListeners();
  }
  
  // Now Playing coordination
  void setNowPlayingOpen(bool isOpen) {
    _isNowPlayingOpen = isOpen;
    notifyListeners();
  }
  
  // Cover art color extraction
  Future<void> extractColorsFromCoverArt(String imageUrl) async {
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
        maximumColorCount: 5,
      );
      
      _glowColors = [
        palette.vibrantColor?.color ?? Colors.purple,
        palette.lightVibrantColor?.color ?? Colors.purpleAccent,
        palette.darkVibrantColor?.color ?? Colors.deepPurple,
      ];
      
      notifyListeners();
    } catch (e) {
      // Fallback to genre gradient
      _glowColors = [];
    }
  }
  
  // Persistence
  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _form = PlayerForm.values[prefs.getInt('player_form') ?? 0];
    _mode = PlayerMode.values[prefs.getInt('player_mode') ?? 0];
    
    final x = prefs.getDouble('player_position_x') ?? 0.0;
    final y = prefs.getDouble('player_position_y') ?? 0.0;
    
    // Restore as screen fraction, clamp to safe area
    _position = _restorePosition(x, y);
    
    notifyListeners();
  }
  
  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('player_form', _form.index);
    await prefs.setInt('player_mode', _mode.index);
    
    // Store as screen fraction for rotation survival
    final screenFraction = _positionToScreenFraction(_position);
    await prefs.setDouble('player_position_x', screenFraction.dx);
    await prefs.setDouble('player_position_y', screenFraction.dy);
  }
  
  // Helper methods
  DragDirection _classifyDirection(Offset delta) {
    final angle = (delta.direction.abs() * 180 / pi);
    
    if (angle < 20) {
      // Vertical
      return delta.dy < 0 ? DragDirection.vertical : DragDirection.vertical;
    } else if (angle >= 20 && angle <= 70) {
      // Diagonal
      if (delta.dy < 0) {
        return delta.dx < 0 ? DragDirection.diagonalUpLeft : DragDirection.diagonalUpRight;
      }
      return DragDirection.ignored;
    } else {
      // Too horizontal, ignore
      return DragDirection.ignored;
    }
  }
  
  bool _isInBottomExtremeZone() {
    // Bottom safe area + bottom nav height
    final screenHeight = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.height /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return _position.dy > screenHeight - 120;
  }
  
  bool _isInTopExtremeZone() {
    // Top safe area + 72dp band
    return _position.dy < 72;
  }
  
  void _morphToBarAndDock() {
    _form = PlayerForm.bar;
    _mode = PlayerMode.auto;
    _recalculateAutoPosition();
    _persistState();
  }
  
  void _morphToPill() {
    _form = PlayerForm.pill;
    _mode = PlayerMode.manual;
    // Position at horizontal center, top + 80dp
    final screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    _position = Offset(screenWidth / 2 - 80, 80); // 160dp pill width
    _persistState();
  }
  
  void _handleDismiss() {
    // Stop playback and clear track
    // Will be handled by PlayerProvider
    notifyListeners();
  }
  
  Rect _getDockRect() {
    final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return Rect.fromLTWH(
      0,
      screenSize.height - 120, // Bottom nav + padding
      screenSize.width,
      120,
    );
  }
  
  Offset _positionToScreenFraction(Offset position) {
    final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return Offset(
      position.dx / screenSize.width,
      position.dy / screenSize.height,
    );
  }
  
  Offset _restorePosition(double fractionX, double fractionY) {
    final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final safeArea = WidgetsBinding.instance.platformDispatcher.views.first.padding /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    
    final x = (fractionX * screenSize.width).clamp(
      safeArea.left + 16,
      screenSize.width - safeArea.right - 16,
    );
    final y = (fractionY * screenSize.height).clamp(
      safeArea.top + 16,
      screenSize.height - safeArea.bottom - 16,
    );
    
    return Offset(x, y);
  }
}

enum DragDirection {
  vertical,
  diagonalUpLeft,
  diagonalUpRight,
  ignored,
}

// Provider
final miniPlayerControllerProvider = ChangeNotifierProvider<MiniPlayerController>((ref) {
  final controller = MiniPlayerController();
  controller.loadState();
  return controller;
});
```

**State Model**:
```dart
class PlayerFormState {
  final PlayerForm form;
  final PlayerMode mode;
  final Offset position;
  final Map<String, Rect> obstacles;
  final bool isDragging;
  final bool isNowPlayingOpen;
  final List<Color> glowColors;
  
  const PlayerFormState({
    required this.form,
    required this.mode,
    required this.position,
    required this.obstacles,
    required this.isDragging,
    required this.isNowPlayingOpen,
    required this.glowColors,
  });
}
```

---

### 3. Player Form Widgets

#### 3.1 BarForm (Enhanced MobileMiniPlayer)

**Location**: `lib/features/player/presentation/widgets/bar_form.dart`

**Interface**:
```dart
class BarForm extends ConsumerWidget {
  final VoidCallback? onExpand;
  final bool isScaled; // True during hold gesture
  
  const BarForm({
    super.key,
    this.onExpand,
    this.isScaled = false,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;
    
    if (track == null) return const SizedBox.shrink();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final safeArea = MediaQuery.of(context).padding;
    
    return AnimatedScale(
      scale: isScaled ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: screenWidth - safeArea.left - safeArea.right,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceElevated,
              AppColors.surfaceElevated.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isScaled ? 0.3 : 0.2),
              blurRadius: isScaled ? 24 : 16,
              offset: Offset(0, isScaled ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Progress line overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: playerState.progressRatio,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.brandPrimary,
                ),
              ),
            ),
            
            // Cover art (44x44)
            GestureDetector(
              onTap: onExpand,
              child: Hero(
                tag: 'player_cover_${track.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.forGenre(track.genre),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.piano_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            
            // Metadata
            Expanded(
              child: GestureDetector(
                onTap: onExpand,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            track.genre,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${playerState.formattedPosition} / ${playerState.formattedDuration}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Controls
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(playerStateProvider.notifier).skipPrevious();
              },
            ),
            _buildPlayPauseButton(playerState, ref),
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(playerStateProvider.notifier).skipNext();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed,
    );
  }
  
  Widget _buildPlayPauseButton(PlayerState state, WidgetRef ref) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppColors.brandPrimary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: AppColors.brandContrast,
          size: 22,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () {
          HapticFeedback.mediumImpact();
          ref.read(playerStateProvider.notifier).togglePlayPause();
        },
      ),
    );
  }
}
```

#### 3.2 CardForm

**Location**: `lib/features/player/presentation/widgets/card_form.dart`

**Interface**:
```dart
class CardForm extends ConsumerWidget {
  final VoidCallback? onExpand;
  
  const CardForm({super.key, this.onExpand});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;
    
    if (track == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: onExpand,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          gradient: AppGradients.forGenre(track.genre),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brandPrimary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Cover art gradient
            Center(
              child: Icon(
                Icons.piano_rounded,
                size: 48,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            
            // Progress overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      playerState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(playerState.progressRatio * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3.3 PillForm with Glow

**Location**: `lib/features/player/presentation/widgets/pill_form.dart`

**Interface**:
```dart
class PillForm extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;
  
  const PillForm({super.key, this.onExpand});
  
  @override
  ConsumerState<PillForm> createState() => _PillFormState();
}

class _PillFormState extends ConsumerState<PillForm>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.5;
  
  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 33), // 30fps
      vsync: this,
    );
    
    _startAmplitudeSampling();
  }
  
  void _startAmplitudeSampling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _sampleAmplitude(),
    );
  }
  
  void _sampleAmplitude() {
    final playerState = ref.read(playerStateProvider);
    
    if (!playerState.isPlaying) {
      // Static breathe when paused
      final breathe = (sin(DateTime.now().millisecondsSinceEpoch / 1000) + 1) / 2;
      setState(() => _currentAmplitude = breathe * 0.5);
      return;
    }
    
    // Sample waveform peaks at current position
    // TODO: Implement actual waveform peak sampling
    // For now, simulate with random values
    setState(() {
      _currentAmplitude = 0.3 + (Random().nextDouble() * 0.7);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;
    final controller = ref.watch(miniPlayerControllerProvider);
    
    if (track == null) return const SizedBox.shrink();
    
    // Check reduce motion setting
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final intensity = reduceMotion ? 0.5 : _currentAmplitude;
    
    return GestureDetector(
      onTap: widget.onExpand,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: GlowPainter(
            colors: controller.glowColors.isNotEmpty
                ? controller.glowColors
                : [
                    AppGradients.forGenre(track.genre).colors.first,
                    AppGradients.forGenre(track.genre).colors.last,
                  ],
            intensity: intensity,
          ),
          child: Container(
            width: 160,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceElevated,
                  AppColors.surfaceElevated.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.brandPrimary.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppGradients.forGenre(track.genre),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.piano_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  playerState.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.brandPrimary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _glowController.dispose();
    _amplitudeTimer?.cancel();
    super.dispose();
  }
}

/// Custom painter for radial glow effect
class GlowPainter extends CustomPainter {
  final List<Color> colors;
  final double intensity;
  
  GlowPainter({
    required this.colors,
    required this.intensity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Create radial gradient
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [
        colors[0].withOpacity(intensity * 0.6),
        colors.length > 1
            ? colors[1].withOpacity(intensity * 0.4)
            : colors[0].withOpacity(intensity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(
          center: center,
          radius: size.width,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    
    canvas.drawCircle(center, size.width, paint);
  }
  
  @override
  bool shouldRepaint(GlowPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
           oldDelegate.colors != colors;
  }
}
```

---

### 4. PlayerObstacle Widget

**Purpose**: Registers bottom-anchored UI elements with the controller for auto-mode avoidance.

**Location**: `lib/features/player/presentation/widgets/player_obstacle.dart`

**Interface**:
```dart
class PlayerObstacle extends StatefulWidget {
  final Widget child;
  final String? id;
  
  const PlayerObstacle({
    super.key,
    required this.child,
    this.id,
  });
  
  @override
  State<PlayerObstacle> createState() => _PlayerObstacleState();
}

class _PlayerObstacleState extends State<PlayerObstacle> {
  final GlobalKey _key = GlobalKey();
  String? _obstacleId;
  
  @override
  void initState() {
    super.initState();
    _obstacleId = widget.id ?? 'obstacle_${hashCode}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerObstacle());
  }
  
  @override
  void didUpdateWidget(PlayerObstacle oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerObstacle());
  }
  
  void _registerObstacle() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !mounted) return;
    
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    
    // Get controller and register
    final container = ProviderScope.containerOf(context);
    container.read(miniPlayerControllerProvider).registerObstacle(
      _obstacleId!,
      rect,
    );
  }
  
  @override
  void dispose() {
    if (mounted) {
      final container = ProviderScope.containerOf(context);
      container.read(miniPlayerControllerProvider).unregisterObstacle(
        _obstacleId!,
      );
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}
```

**Usage Example**:
```dart
// In content_studio_dock_view.dart
class ContentStudioDock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlayerObstacle(
      id: 'content_studio_dock',
      child: Container(
        height: 200,
        // ... dock UI
      ),
    );
  }
}
```

---

### 5. Now Playing Cockpit Updates

**Location**: `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`

**Required Changes**:

1. **Material Transparency Wrapper**:
```dart
@override
Widget build(BuildContext context) {
  // ...
  return Material(
    type: MaterialType.transparency,
    child: Container(
      // ... existing modal content
    ),
  );
}
```

2. **Duplicate Element Removal**:
- Remove duplicate heart icon from utility tray (keep only header version)
- Remove duplicate lyrics icon from header (keep only tab version)

3. **Control Implementation**:

**Shuffle Toggle** (Already implemented):
```dart
IconButton(
  icon: Icon(
    Icons.shuffle_rounded,
    color: playerState.isShuffle ? AppColors.brandPrimary : AppColors.textSecondary,
  ),
  onPressed: () {
    HapticFeedback.selectionClick();
    notifier.toggleShuffle();
  },
)
```

**Repeat Mode Cycle** (Already implemented):
```dart
IconButton(
  icon: Icon(
    playerState.repeatMode == AudioRepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded,
    color: playerState.repeatMode != AudioRepeatMode.off
        ? AppColors.brandPrimary
        : AppColors.textTertiary,
  ),
  onPressed: () {
    HapticFeedback.selectionClick();
    notifier.cycleRepeatMode();
  },
)
```

**Share Action** (needs visibility check):
```dart
void _handleShare(BuildContext context, Track track) async {
  final libraryTrack = ref.read(libraryTracksProvider)
      .cast<LibraryTrack?>()
      .firstWhere((t) => t?.id == track.id, orElse: () => null);
  
  if (libraryTrack?.visibility == TrackVisibility.private) {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Track Public?'),
        content: const Text(
          'This track is private. Make it public to share?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make Public'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Update visibility
    await ref.read(libraryTracksProvider.notifier)
        .updateVisibility(track.id, TrackVisibility.public);
  }
  
  // Open system share sheet
  await Share.share(
    'Check out "${track.title}" by ${track.creatorName} on Vhunambi!\n'
    'https://vhunambi.com/track/${track.id}',
    subject: track.title,
  );
}
```

4. **Action Row Horizontal Scroll**:
```dart
Container(
  margin: const EdgeInsets.symmetric(horizontal: 24),
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  decoration: BoxDecoration(
    color: AppColors.surfaceSecondary,
    borderRadius: AppRadius.pillBorder,
    border: Border.all(color: AppColors.borderSubtle),
  ),
  child: Stack(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _UtilityItem(icon: Icons.lyrics_outlined, label: 'Lyrics', onTap: () {}),
            _UtilityItem(icon: Icons.tune_rounded, label: 'Stems', onTap: () {}),
            _UtilityItem(icon: Icons.info_outline_rounded, label: 'Details', onTap: () {}),
            _UtilityItem(icon: Icons.ios_share_rounded, label: 'Share', onTap: () {}),
            _UtilityItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: () {}),
          ],
        ),
      ),
      
      // Gradient fade indicators
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceSecondary,
                AppColors.surfaceSecondary.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceSecondary.withOpacity(0),
                AppColors.surfaceSecondary,
              ],
            ),
          ),
        ),
      ),
    ],
  ),
)
```

5. **Duration Label Fix**:
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      playerState.formattedPosition,
      style: AppTypography.caption,
    ),
    SizedBox(
      width: 48, // Fixed width to prevent truncation
      child: Text(
        playerState.formattedDuration,
        style: AppTypography.caption,
        textAlign: TextAlign.right,
      ),
    ),
  ],
)
```

6. **Title Long Press Expansion**:
```dart
class _ExpandableTitle extends StatefulWidget {
  final String title;
  
  const _ExpandableTitle({required this.title});
  
  @override
  State<_ExpandableTitle> createState() => _ExpandableTitleState();
}

class _ExpandableTitleState extends State<_ExpandableTitle> {
  bool _isExpanded = false;
  Timer? _collapseTimer;
  
  void _handleLongPress() {
    setState(() => _isExpanded = true);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(
      const Duration(seconds: 3),
      () => setState(() => _isExpanded = false),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _handleLongPress,
      child: Text(
        widget.title,
        style: AppTypography.titleLarge.copyWith(fontSize: 22),
        maxLines: _isExpanded ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  
  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }
}
```

## Data Models

### PlayerFormState
```dart
enum PlayerForm { bar, card, pill }
enum PlayerMode { auto, manual }

@immutable
class PlayerFormState {
  final PlayerForm form;
  final PlayerMode mode;
  final Offset position;
  final Map<String, Rect> obstacles;
  final bool isDragging;
  final DragDirection? dragDirection;
  final bool isNowPlayingOpen;
  final List<Color> glowColors;
  
  const PlayerFormState({
    required this.form,
    required this.mode,
    required this.position,
    this.obstacles = const {},
    this.isDragging = false,
    this.dragDirection,
    this.isNowPlayingOpen = false,
    this.glowColors = const [],
  });
  
  PlayerFormState copyWith({
    PlayerForm? form,
    PlayerMode? mode,
    Offset? position,
    Map<String, Rect>? obstacles,
    bool? isDragging,
    DragDirection? dragDirection,
    bool? isNowPlayingOpen,
    List<Color>? glowColors,
  }) {
    return PlayerFormState(
      form: form ?? this.form,
      mode: mode ?? this.mode,
      position: position ?? this.position,
      obstacles: obstacles ?? this.obstacles,
      isDragging: isDragging ?? this.isDragging,
      dragDirection: dragDirection ?? this.dragDirection,
      isNowPlayingOpen: isNowPlayingOpen ?? this.isNowPlayingOpen,
      glowColors: glowColors ?? this.glowColors,
    );
  }
}
```

### Enhanced PlayerState
```dart
// Add to existing player_state.dart
class PlayerState {
  // ... existing fields
  
  // New fields for waveform peaks
  final List<double>? waveformPeaks;
  final int waveformSampleRate;
  
  const PlayerState({
    // ... existing params
    this.waveformPeaks,
    this.waveformSampleRate = 44100,
  });
  
  // Method to sample amplitude at current position
  double getAmplitudeAtPosition() {
    if (waveformPeaks == null || waveformPeaks!.isEmpty) {
      return 0.5; // Default mid-range
    }
    
    final durationMs = duration.inMilliseconds;
    final positionMs = position.inMilliseconds;
    
    if (durationMs == 0) return 0.5;
    
    final progress = positionMs / durationMs;
    final index = (progress * waveformPeaks!.length).floor()
        .clamp(0, waveformPeaks!.length - 1);
    
    return waveformPeaks![index];
  }
}
```

## Gesture System

### Gesture Recognition Flow

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Detecting: Long Press 350ms
    Detecting --> Cancelled: Release Early
    Detecting --> DirectionClassifying: 24dp Travel
    DirectionClassifying --> VerticalDrag: Angle < 20°
    DirectionClassifying --> DiagonalDrag: 20° ≤ Angle ≤ 70°
    DirectionClassifying --> Ignored: Angle > 70°
    VerticalDrag --> ExtremeZoneCheck: Release
    DiagonalDrag --> FormMorph: Release
    Ignored --> Idle
    ExtremeZoneCheck --> BottomZone: In Bottom Zone
    ExtremeZoneCheck --> TopZone: In Top Zone
    ExtremeZoneCheck --> ManualMode: Outside Zones
    BottomZone --> BarAutoMode: Morph Complete
    TopZone --> PillManualMode: Morph Complete
    FormMorph --> ManualMode: Morph Complete
    BarAutoMode --> Idle
    PillManualMode --> Idle
    ManualMode --> Idle
```

### Gesture Recognizer Configuration

```dart
class GestureRecognitionLayer extends StatelessWidget {
  final Widget child;
  final Function(Offset) onDragStart;
  final Function(Offset) onDragUpdate;
  final Function(Velocity) onDragEnd;
  
  const GestureRecognitionLayer({
    super.key,
    required this.child,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });
  
  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 350),
          ),
          (instance) {
            instance
              ..onLongPressStart = (details) {
                HapticFeedback.mediumImpact();
                onDragStart(details.globalPosition);
              }
              ..onLongPressMoveUpdate = (details) {
                onDragUpdate(details.globalPosition);
              }
              ..onLongPressEnd = (details) {
                onDragEnd(Velocity.zero); // Calculate actual velocity
              };
          },
        ),
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (instance) {
            instance
              ..onEnd = (details) {
                if (details.primaryVelocity?.abs() ?? 0 > 250) {
                  onDragEnd(details.velocity);
                }
              };
          },
        ),
      },
      child: child,
    );
  }
}
```

### Direction Classification Algorithm

```dart
enum DragDirection {
  vertical,
  diagonalUpLeft,
  diagonalUpRight,
  ignored,
}

DragDirection classifyDirection(Offset delta) {
  // Calculate angle from vertical axis
  final angle = (atan2(delta.dx.abs(), delta.dy.abs()) * 180 / pi);
  
  if (angle < 20) {
    // Vertical (< 20 degrees from vertical)
    return DragDirection.vertical;
  } else if (angle >= 20 && angle <= 70) {
    // Diagonal (20-70 degrees)
    if (delta.dy < 0) {
      // Upward diagonal
      return delta.dx < 0
          ? DragDirection.diagonalUpLeft
          : DragDirection.diagonalUpRight;
    } else {
      // Downward diagonal - ignore
      return DragDirection.ignored;
    }
  } else {
    // Too horizontal (> 70 degrees) - ignore
    return DragDirection.ignored;
  }
}
```

### Extreme Zone Detection

```dart
class ExtremeZoneDetector {
  static const double topZoneHeight = 72.0; // Status bar + band
  static const double bottomZoneHeight = 120.0; // Nav + padding
  
  static ExtremeZone? detectZone(Offset position, Size screenSize, EdgeInsets safeArea) {
    final topThreshold = safeArea.top + topZoneHeight;
    final bottomThreshold = screenSize.height - bottomZoneHeight;
    
    if (position.dy < topThreshold) {
      return ExtremeZone.top;
    } else if (position.dy > bottomThreshold) {
      return ExtremeZone.bottom;
    }
    
    return null;
  }
  
  static Widget buildZoneHighlight(
    BuildContext context,
    ExtremeZone zone,
    Size screenSize,
    EdgeInsets safeArea,
  ) {
    return Positioned(
      top: zone == ExtremeZone.top ? safeArea.top : null,
      bottom: zone == ExtremeZone.bottom ? 0 : null,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: zone == ExtremeZone.top ? topZoneHeight : bottomZoneHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: zone == ExtremeZone.top ? Alignment.topCenter : Alignment.bottomCenter,
              end: zone == ExtremeZone.top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                AppColors.brandPrimary.withOpacity(0.3),
                AppColors.brandPrimary.withOpacity(0.0),
              ],
            ),
            border: Border(
              top: zone == ExtremeZone.top
                  ? BorderSide(color: AppColors.brandPrimary, width: 2)
                  : BorderSide.none,
              bottom: zone == ExtremeZone.bottom
                  ? BorderSide(color: AppColors.brandPrimary, width: 2)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

enum ExtremeZone { top, bottom }
```

## Animation Design

### Morph Animation Specifications

**Duration**: 260-300ms  
**Curve**: `Curves.easeOutCubic`  
**Interpolation**: Rect, borderRadius, shadow elevation

```dart
class MorphAnimator {
  static const Duration morphDuration = Duration(milliseconds: 280);
  static const Curve morphCurve = Curves.easeOutCubic;
  
  static RectTween createMorphTween(PlayerForm from, PlayerForm to) {
    return RectTween(
      begin: _getRectForForm(from),
      end: _getRectForForm(to),
    );
  }
  
  static Rect _getRectForForm(PlayerForm form) {
    switch (form) {
      case PlayerForm.bar:
        return const Rect.fromLTWH(0, 0, 375, 64); // Full width
      case PlayerForm.card:
        return const Rect.fromLTWH(0, 0, 128, 128); // Square
      case PlayerForm.pill:
        return const Rect.fromLTWH(0, 0, 160, 48); // Pill
    }
  }
  
  static BorderRadiusTween createRadiusTween(PlayerForm from, PlayerForm to) {
    return BorderRadiusTween(
      begin: _getRadiusForForm(from),
      end: _getRadiusForForm(to),
    );
  }
  
  static BorderRadius _getRadiusForForm(PlayerForm form) {
    switch (form) {
      case PlayerForm.bar:
        return BorderRadius.circular(16);
      case PlayerForm.card:
        return BorderRadius.circular(16);
      case PlayerForm.pill:
        return BorderRadius.circular(24);
    }
  }
  
  static Tween<double> createElevationTween(PlayerForm from, PlayerForm to) {
    return Tween<double>(
      begin: _getElevationForForm(from),
      end: _getElevationForForm(to),
    );
  }
  
  static double _getElevationForForm(PlayerForm form) {
    switch (form) {
      case PlayerForm.bar:
        return 8.0;
      case PlayerForm.card:
        return 12.0;
      case PlayerForm.pill:
        return 16.0;
    }
  }
}
```

### Position Animation

```dart
class PositionAnimator {
  static const Duration positionDuration = Duration(milliseconds: 200);
  static const Curve positionCurve = Curves.easeOutCubic;
  
  static Animation<Offset> createPositionAnimation(
    AnimationController controller,
    Offset from,
    Offset to,
  ) {
    return Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: controller,
        curve: positionCurve,
      ),
    );
  }
}
```

### Glow Animation Performance

**Target**: 30fps (33ms frame budget)  
**Optimization**: `RepaintBoundary`, cached `Paint` objects, throttled updates

```dart
class OptimizedGlowAnimation {
  static const Duration frameBudget = Duration(milliseconds: 33);
  DateTime _lastUpdate = DateTime.now();
  
  bool shouldUpdate() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastUpdate);
    
    if (elapsed >= frameBudget) {
      _lastUpdate = now;
      return true;
    }
    
    return false;
  }
}

class CachedGlowPainter extends CustomPainter {
  final List<Color> colors;
  final double intensity;
  late final Paint _glowPaint;
  
  CachedGlowPainter({
    required this.colors,
    required this.intensity,
  }) {
    _glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    _glowPaint.shader = RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [
        colors[0].withOpacity(intensity * 0.6),
        colors.length > 1
            ? colors[1].withOpacity(intensity * 0.4)
            : colors[0].withOpacity(intensity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: size.width),
    );
    
    canvas.drawCircle(center, size.width, _glowPaint);
  }
  
  @override
  bool shouldRepaint(CachedGlowPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
```

### Haptic Feedback Schedule

```dart
class HapticSchedule {
  static void onLongPressStart() {
    HapticFeedback.mediumImpact();
  }
  
  static void onEnterExtremeZone() {
    HapticFeedback.selectionClick();
  }
  
  static void onMorphComplete() {
    HapticFeedback.lightImpact();
  }
  
  static void onDismiss() {
    HapticFeedback.heavyImpact();
  }
  
  static void onControlTap() {
    HapticFeedback.selectionClick();
  }
}
```

## State Persistence

### SharedPreferences Schema

```dart
class PlayerPersistence {
  static const String keyForm = 'player_form';
  static const String keyMode = 'player_mode';
  static const String keyPositionX = 'player_position_x';
  static const String keyPositionY = 'player_position_y';
  static const String keyShuffle = 'playback_shuffle';
  static const String keyRepeat = 'playback_repeat';
  
  static Future<void> saveState(MiniPlayerController controller) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(keyForm, controller.form.index);
    await prefs.setInt(keyMode, controller.mode.index);
    
    // Save as screen fraction (0.0 - 1.0)
    final screenSize = _getScreenSize();
    await prefs.setDouble(
      keyPositionX,
      controller.position.dx / screenSize.width,
    );
    await prefs.setDouble(
      keyPositionY,
      controller.position.dy / screenSize.height,
    );
  }
  
  static Future<PlayerFormState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final form = PlayerForm.values[prefs.getInt(keyForm) ?? 0];
    final mode = PlayerMode.values[prefs.getInt(keyMode) ?? 0];
    
    final fractionX = prefs.getDouble(keyPositionX) ?? 0.0;
    final fractionY = prefs.getDouble(keyPositionY) ?? 0.0;
    
    // Restore and clamp to safe area
    final position = _restorePosition(fractionX, fractionY);
    
    return PlayerFormState(
      form: form,
      mode: mode,
      position: position,
    );
  }
  
  static Offset _restorePosition(double fractionX, double fractionY) {
    final screenSize = _getScreenSize();
    final safeArea = _getSafeArea();
    
    final x = (fractionX * screenSize.width).clamp(
      safeArea.left + 16,
      screenSize.width - safeArea.right - 16,
    );
    
    final y = (fractionY * screenSize.height).clamp(
      safeArea.top + 16,
      screenSize.height - safeArea.bottom - 16,
    );
    
    return Offset(x, y);
  }
  
  static Size _getScreenSize() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize / view.devicePixelRatio;
  }
  
  static EdgeInsets _getSafeArea() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.padding / view.devicePixelRatio;
  }
}
```

## Error Handling

### Obstacle Registration Failures

```dart
class ObstacleRegistry {
  final Map<String, Rect> _obstacles = {};
  
  void registerObstacle(String id, Rect rect) {
    try {
      if (rect.isEmpty || !rect.isFinite) {
        debugPrint('Invalid obstacle rect: $id');
        return;
      }
      
      _obstacles[id] = rect;
    } catch (e) {
      debugPrint('Failed to register obstacle $id: $e');
    }
  }
  
  void unregisterObstacle(String id) {
    try {
      _obstacles.remove(id);
    } catch (e) {
      debugPrint('Failed to unregister obstacle $id: $e');
    }
  }
}
```

### Color Extraction Failures

```dart
Future<List<Color>> extractColorsWithFallback(String? imageUrl, String genre) async {
  if (imageUrl == null || imageUrl.isEmpty) {
    return _getGenreColors(genre);
  }
  
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      NetworkImage(imageUrl),
      size: const Size(100, 100),
      maximumColorCount: 5,
      timeout: const Duration(seconds: 5),
    );
    
    return [
      palette.vibrantColor?.color ?? _getGenreColors(genre)[0],
      palette.lightVibrantColor?.color ?? _getGenreColors(genre)[1],
      palette.darkVibrantColor?.color ?? _getGenreColors(genre)[2],
    ];
  } catch (e) {
    debugPrint('Color extraction failed: $e');
    return _getGenreColors(genre);
  }
}

List<Color> _getGenreColors(String genre) {
  final gradient = AppGradients.forGenre(genre);
  return [
    gradient.colors.first,
    gradient.colors.last,
    gradient.colors.first,
  ];
}
```

### Animation Performance Degradation

```dart
class PerformanceMonitor {
  static const int targetFps = 60;
  static const Duration frameBudget = Duration(milliseconds: 16);
  
  final List<Duration> _frameTimes = [];
  int _droppedFrames = 0;
  
  void recordFrame(Duration frameTime) {
    _frameTimes.add(frameTime);
    
    if (frameTime > frameBudget) {
      _droppedFrames++;
    }
    
    // Keep last 60 frames
    if (_frameTimes.length > 60) {
      _frameTimes.removeAt(0);
    }
  }
  
  bool shouldReduceQuality() {
    if (_frameTimes.length < 30) return false;
    
    // If >20% frames dropped, reduce quality
    final dropRate = _droppedFrames / _frameTimes.length;
    return dropRate > 0.2;
  }
  
  void reset() {
    _frameTimes.clear();
    _droppedFrames = 0;
  }
}
```

## Property-Based Testing Applicability

**PBT is NOT applicable to this feature.** This is a UI rendering and gesture interaction feature that falls outside the appropriate scope for property-based testing:

1. **UI Rendering**: The three player forms (Bar, Card, Pill) are primarily visual components with layout, styling, and animation concerns
2. **Gesture Recognition**: Hold-drag, fling, and direction classification involve platform gesture recognizers and haptic feedback - side effects that cannot be tested as pure functions
3. **Animation Controllers**: Morph animations, position transitions, and glow effects rely on Flutter's animation framework with stateful controllers
4. **External Dependencies**: Palette extraction, SharedPreferences persistence, and MediaQuery access involve I/O and platform APIs

**Testing Strategy**: This feature uses a combination of:
- **Unit tests** for pure logic (direction classification, extreme zone detection, position clamping)
- **Widget tests** for component rendering and basic interactions
- **Integration tests** for end-to-end gesture flows
- **Performance benchmarks** for animation smoothness and memory usage

The absence of correctness properties does not indicate incomplete design - it reflects appropriate tool selection for UI/UX features.

## Testing Strategy

### Unit Testing

**Test Categories**:
1. **Direction Classification**: Verify angle calculations and direction mapping
2. **Extreme Zone Detection**: Test boundary conditions and zone overlap
3. **Position Clamping**: Ensure safe area constraints are respected
4. **State Persistence**: Verify screen fraction calculations survive rotation
5. **Obstacle Registry**: Test registration, unregistration, and position calculation

**Example Unit Test**:
```dart
void main() {
  group('Direction Classification', () {
    test('vertical drag (<20°) is classified as vertical', () {
      final delta = const Offset(5, 50); // ~5.7° from vertical
      expect(classifyDirection(delta), DragDirection.vertical);
    });
    
    test('diagonal drag (20-70°) upward-left is classified correctly', () {
      final delta = const Offset(-30, -40); // ~36.9° from vertical
      expect(classifyDirection(delta), DragDirection.diagonalUpLeft);
    });
    
    test('horizontal drag (>70°) is ignored', () {
      final delta = const Offset(50, 5); // ~84.3° from vertical
      expect(classifyDirection(delta), DragDirection.ignored);
    });
  });
  
  group('Extreme Zone Detection', () {
    test('position in top zone returns ExtremeZone.top', () {
      final position = const Offset(100, 50);
      final screenSize = const Size(375, 812);
      final safeArea = const EdgeInsets.only(top: 44);
      
      final zone = ExtremeZoneDetector.detectZone(position, screenSize, safeArea);
      expect(zone, ExtremeZone.top);
    });
    
    test('position in bottom zone returns ExtremeZone.bottom', () {
      final position = const Offset(100, 750);
      final screenSize = const Size(375, 812);
      final safeArea = const EdgeInsets.only(bottom: 34);
      
      final zone = ExtremeZoneDetector.detectZone(position, screenSize, safeArea);
      expect(zone, ExtremeZone.bottom);
    });
    
    test('position outside zones returns null', () {
      final position = const Offset(100, 400);
      final screenSize = const Size(375, 812);
      final safeArea = const EdgeInsets.only(top: 44, bottom: 34);
      
      final zone = ExtremeZoneDetector.detectZone(position, screenSize, safeArea);
      expect(zone, null);
    });
  });
  
  group('Obstacle Registry', () {
    test('registers and calculates highest obstacle', () {
      final registry = ObstacleRegistry();
      
      registry.registerObstacle('dock1', const Rect.fromLTWH(0, 700, 375, 100));
      registry.registerObstacle('dock2', const Rect.fromLTWH(0, 650, 375, 50));
      
      final targetY = registry.calculateTargetY(
        dockRect: const Rect.fromLTWH(0, 680, 375, 120),
      );
      
      expect(targetY, 642.0); // 650 - 8dp padding
    });
  });
}
```

### Widget Testing

**Test Categories**:
1. **BarForm Rendering**: Verify controls, progress, metadata display
2. **CardForm Rendering**: Verify 128dp size, progress percentage
3. **PillForm Rendering**: Verify glow animation, pause/play state
4. **MiniPlayerHost Hiding**: Test keyboard, route, Now Playing visibility
5. **Gesture Recognition**: Simulate long press, drag, fling

**Example Widget Test**:
```dart
void main() {
  testWidgets('BarForm displays track metadata and controls', (tester) async {
    final track = Track(
      id: 'test_1',
      title: 'Test Track',
      genre: 'Afrobeat',
      creatorName: 'Test Artist',
      duration: const Duration(minutes: 3, seconds: 45),
    );
    
    final playerState = PlayerState(
      currentTrack: track,
      playbackStatus: PlaybackStatus.playing,
      position: const Duration(minutes: 1, seconds: 30),
      duration: const Duration(minutes: 3, seconds: 45),
    );
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerStateProvider.overrideWith((ref) => playerState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BarForm(onExpand: () {}),
          ),
        ),
      ),
    );
    
    // Verify metadata
    expect(find.text('Test Track'), findsOneWidget);
    expect(find.text('Afrobeat'), findsOneWidget);
    expect(find.text('1:30 / 3:45'), findsOneWidget);
    
    // Verify controls
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
  });
  
  testWidgets('PillForm renders with glow when playing', (tester) async {
    final track = Track(
      id: 'test_1',
      title: 'Test Track',
      genre: 'Afrobeat',
    );
    
    final playerState = PlayerState(
      currentTrack: track,
      playbackStatus: PlaybackStatus.playing,
    );
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerStateProvider.overrideWith((ref) => playerState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PillForm(onExpand: () {}),
          ),
        ),
      ),
    );
    
    // Verify glow painter is present
    expect(find.byType(CustomPaint), findsOneWidget);
    
    // Verify play icon when playing
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}
```

### Integration Testing

**Test Scenarios**:
1. **End-to-End Morph Flow**: Bar → diagonal drag → Card → drag to top → Pill → drag to bottom → Bar
2. **Auto Mode Obstacle Avoidance**: Register obstacle, verify Bar moves up, unregister, verify Bar returns
3. **Dismiss Gesture**: Horizontal fling, verify player disappears and track stops
4. **State Persistence**: Set manual position, restart app, verify position restored
5. **Now Playing Coordination**: Open cockpit, verify player hidden, close cockpit, verify player restored

**Example Integration Test**:
```dart
void main() {
  testWidgets('Complete morph flow from Bar to Pill and back', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            return Stack(
              children: [
                child!,
                const MiniPlayerHost(),
              ],
            );
          },
          home: const Scaffold(
            body: Center(child: Text('Home')),
          ),
        ),
      ),
    );
    
    // Start with Bar form
    expect(find.byType(BarForm), findsOneWidget);
    
    // Simulate long press + diagonal drag (upward-right)
    final barCenter = tester.getCenter(find.byType(BarForm));
    final testGesture = await tester.startGesture(barCenter);
    await tester.pump(const Duration(milliseconds: 350)); // Hold
    await testGesture.moveBy(const Offset(50, -50)); // Diagonal
    await tester.pump(const Duration(milliseconds: 50));
    await testGesture.up();
    await tester.pumpAndSettle();
    
    // Verify morphed to Card
    expect(find.byType(CardForm), findsOneWidget);
    
    // Drag to top zone
    final cardCenter = tester.getCenter(find.byType(CardForm));
    await tester.drag(find.byType(CardForm), Offset(0, -cardCenter.dy + 50));
    await tester.pumpAndSettle();
    
    // Verify morphed to Pill
    expect(find.byType(PillForm), findsOneWidget);
    
    // Drag to bottom zone
    final pillCenter = tester.getCenter(find.byType(PillForm));
    final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
    await tester.drag(
      find.byType(PillForm),
      Offset(0, screenHeight - pillCenter.dy - 50),
    );
    await tester.pumpAndSettle();
    
    // Verify morphed back to Bar in Auto mode
    expect(find.byType(BarForm), findsOneWidget);
  });
}
```

### Performance Testing

**Metrics**:
- **Frame Rate**: Maintain 60fps during drag gestures
- **Animation Smoothness**: Zero dropped frames during 280ms morph
- **Glow Render Time**: <33ms per frame (30fps target)
- **Memory Usage**: <10MB increase for glow animation
- **Battery Impact**: <5% increase during 1-hour playback with glow

**Benchmarking**:
```dart
void main() {
  testWidgets('Glow animation maintains 30fps', (tester) async {
    final stopwatch = Stopwatch()..start();
    int frameCount = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PillForm(onExpand: () {}),
        ),
      ),
    );
    
    // Run for 3 seconds
    while (stopwatch.elapsedMilliseconds < 3000) {
      await tester.pump(const Duration(milliseconds: 33));
      frameCount++;
    }
    
    final avgFps = frameCount / (stopwatch.elapsedMilliseconds / 1000);
    expect(avgFps, greaterThanOrEqualTo(28)); // Allow 2fps variance
  });
}
```

### Accessibility Testing

**Requirements**:
1. Semantic labels for all player forms
2. Custom semantic actions for morphing
3. Screen reader announcements for state changes
4. Touch target sizes (minimum 44x44dp)
5. Contrast ratios meet WCAG AA standards

**Example Test**:
```dart
void main() {
  testWidgets('BarForm has proper semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarForm(onExpand: () {}),
        ),
      ),
    );
    
    // Verify semantic labels
    final semantics = tester.getSemantics(find.byType(BarForm));
    expect(semantics.label, contains('Playing'));
    
    // Verify custom actions
    expect(
      semantics.customSemanticsActions.keys,
      containsAll([
        'Dock player',
        'Move to top',
        'Convert to card',
      ]),
    );
  });
  
  testWidgets('All controls meet 44x44dp minimum', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarForm(onExpand: () {}),
        ),
      ),
    );
    
    // Check previous button
    final prevButton = tester.getSize(
      find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
    );
    expect(prevButton.width, greaterThanOrEqualTo(44));
    expect(prevButton.height, greaterThanOrEqualTo(44));
    
    // Check play/pause button
    final playButton = tester.getSize(
      find.widgetWithIcon(IconButton, Icons.pause_rounded),
    );
    expect(playButton.width, greaterThanOrEqualTo(44));
    expect(playButton.height, greaterThanOrEqualTo(44));
    
    // Check next button
    final nextButton = tester.getSize(
      find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
    );
    expect(nextButton.width, greaterThanOrEqualTo(44));
    expect(nextButton.height, greaterThanOrEqualTo(44));
  });
}
```

## Implementation Phases

### Phase A: Foundation (Requirements 1, 2, 3, 12)
- Create `MiniPlayerController` with form, mode, position state
- Implement `MiniPlayerHost` mounting via `MaterialApp.builder`
- Add Material transparency wrapper
- Enhance `MobileMiniPlayer` to `BarForm` with genre chip and progress
- Implement `PlayerObstacle` widget and registration system
- Create auto-mode obstacle avoidance logic
- Fix Now Playing Material wrapper

**Deliverables**:
- [ ] `MiniPlayerController` with state management
- [ ] `MiniPlayerHost` globally mounted
- [ ] `BarForm` with enhanced UI
- [ ] `PlayerObstacle` registration working
- [ ] Auto-mode positioning functional
- [ ] Material transparency fixes applied

### Phase B: Gestures and Manual Mode (Requirements 4, 5, 6, 7)
- Implement hold gesture recognition (350ms long press)
- Add direction classification logic
- Create vertical drag tracking
- Implement bottom extreme zone detection and morph to Bar + Auto
- Add horizontal fling dismiss gesture
- Implement state persistence with SharedPreferences
- Add haptic feedback schedule

**Deliverables**:
- [ ] Hold gesture activates manual mode
- [ ] Vertical drag repositions player
- [ ] Bottom zone resets to Bar + Auto
- [ ] Horizontal fling dismisses player
- [ ] State persists across sessions
- [ ] Haptic feedback on gesture milestones

### Phase C: Card Form and Diagonal Morphing (Requirement 8)
- Create `CardForm` widget (128dp square)
- Implement diagonal-up drag detection (20-70°)
- Add edge-snapping logic (left/right based on dx)
- Create morph animation between Bar and Card
- Add free positioning for Card form
- Ensure 16dp safe area clearance

**Deliverables**:
- [ ] `CardForm` renders correctly
- [ ] Diagonal drag from Bar morphs to Card
- [ ] Card snaps to appropriate edge
- [ ] Card can be freely positioned
- [ ] Morph animation smooth (280ms, 60fps)

### Phase D: Pill Form and Glow (Requirements 9, 10, 11)
- Create `PillForm` widget with minimal UI
- Implement top extreme zone detection
- Add morph animation from any form to Pill
- Integrate `palette_generator` for color extraction
- Create `GlowPainter` with CustomPaint
- Implement waveform amplitude sampling
- Add 30fps throttling and RepaintBoundary
- Implement breathe animation for paused state
- Add reduce-motion accessibility support
- Create semantic custom actions

**Deliverables**:
- [ ] `PillForm` renders with glow
- [ ] Top zone triggers Pill morph
- [ ] Glow colors extracted from cover art
- [ ] Glow intensity driven by amplitude
- [ ] Performance meets 30fps target
- [ ] Accessibility actions functional

### Phase E: Now Playing Enhancements (Requirements 13-26)
- Implement chevron close action
- Add heart like/unlike with optimistic UI
- Create lyrics view with sync highlighting
- Implement overflow menu (playlist, download, copy link, visibility, delete)
- Add share action with visibility check
- Enhance waveform seek with preview scrubber
- Implement shuffle toggle persistence
- Create repeat mode cycle (off → all → one)
- Add stems mixer access
- Create details modal
- Fix action row horizontal scroll with fade indicators
- Remove duplicate heart and lyrics controls
- Fix duration label width
- Add title long-press expansion

**Deliverables**:
- [ ] All 12 controls functional
- [ ] Duplicate elements removed
- [ ] Layout fixes applied (scroll, width, truncation)
- [ ] State persistence for shuffle/repeat

## Dependencies

### Flutter Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  shared_preferences: ^2.2.0
  palette_generator: ^0.3.3+2
  
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### System Dependencies
- Android: API level 21+ (Lollipop) for Material effects
- iOS: 12.0+ for haptic engine
- Minimum RAM: 2GB for smooth animations

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Morph Animation | 60fps | No dropped frames during 280ms morph |
| Drag Gesture | 60fps | Smooth tracking during vertical/diagonal drag |
| Glow Animation | 30fps | 33ms frame budget, throttled updates |
| Memory Overhead | <15MB | Heap allocation for glow and animations |
| Battery Impact | <5% | 1-hour playback with glow active |
| Startup Time | <100ms | Controller restoration and first paint |

## Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gesture conflicts with page scrolling | High | Medium | Use `LongPressGestureRecognizer` with 350ms delay to disambiguate |
| Performance degradation on low-end devices | High | Medium | Implement performance monitoring, reduce glow quality if frame drops >20% |
| Obstacle registration lifecycle bugs | Medium | Medium | Use `addPostFrameCallback` for registration, explicit disposal cleanup |
| State persistence breaks on rotation | Medium | Low | Store positions as screen fractions (0.0-1.0), clamp to safe area on restore |
| Color extraction fails or times out | Low | Medium | Fallback to genre gradient, 5-second timeout on extraction |
| Haptic feedback drains battery | Low | Low | Respect system haptics settings, use light/medium impact only |

## Accessibility Compliance

### WCAG 2.1 Level AA Requirements

1. **Perceivable**:
   - Color contrast ratio ≥4.5:1 for text, ≥3:1 for UI components
   - Alternative text for all icons
   - Visual feedback not reliant on color alone

2. **Operable**:
   - All controls accessible via keyboard/switch control
   - Touch targets ≥44x44dp
   - No time limits on user actions
   - Custom semantic actions for gesture alternatives

3. **Understandable**:
   - Semantic labels describe player state
   - State change announcements for screen readers
   - Consistent control behavior across forms

4. **Robust**:
   - Semantic tree properly structured
   - Focus order logical (cover → metadata → controls)
   - Compatible with TalkBack/VoiceOver

### Implementation

```dart
class AccessibleBarForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Music player, now playing: ${track.title} by ${track.creatorName}',
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Dock player'): () => _handleDock(),
        CustomSemanticsAction(label: 'Move to top'): () => _handleMoveTop(),
        CustomSemanticsAction(label: 'Convert to card'): () => _handleConvertCard(),
      },
      child: BarForm(/* ... */),
    );
  }
}
```

## Security Considerations

1. **No Sensitive Data in State**: Player state never contains auth tokens or user credentials
2. **URL Validation**: Cover art URLs validated before network requests
3. **SharedPreferences Isolation**: Player preferences scoped to app, not shared
4. **Memory Safety**: Dispose animation controllers to prevent leaks

## Conclusion

This design provides a comprehensive architecture for the Adaptive Mini Player feature, addressing all 26 requirements with detailed component specifications, gesture handling, animation design, and testing strategies. The phased implementation approach ensures incremental delivery with testable milestones, while performance targets and risk mitigation strategies ensure production-ready quality.

The design prioritizes:
- **User Experience**: Gestural fluidity, zero screen intrusion, visual delight
- **Performance**: 60fps animations, 30fps glow, optimized memory
- **Accessibility**: Semantic actions, screen reader support, WCAG compliance
- **Maintainability**: Clear component separation, comprehensive testing, error handling

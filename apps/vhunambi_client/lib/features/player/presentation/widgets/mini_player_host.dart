import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/services/analytics_service.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/player_state.dart';
import '../providers/mini_player_controller.dart';
import '../providers/player_provider.dart';
import 'expanded_cockpit_modal.dart';
import 'mobile_mini_player.dart';
import 'pill_form.dart';
import '../../../onboarding/presentation/views/splash_view.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';

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

  Offset _grabOffset = Offset.zero;
  bool _isOverBin = false;

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
  void dispose() {
    _morphController.dispose();
    _positionController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(miniPlayerControllerProvider);
    final playerState = ref.watch(playerStateProvider);
    final screenSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final topSafeArea = mediaPadding.top;
    final bottomSafeArea = mediaPadding.bottom;

    // Hide during desktop, no active track, auth/onboarding, keyboard, or Now Playing
    if (_shouldHide(context, controller, playerState)) {
      return const SizedBox.shrink();
    }

    // Scale feedback during hold gesture (1.04x) or hovering over bin (0.85x).
    final dragScale = controller.isDragging ? (_isOverBin ? 0.85 : kHoldGestureScale) : 1.0;

    // Calculate active target position based on mode, form, and obstacles
    final activePosition = controller.calculateAutoPosition(
      screenSize: screenSize,
      bottomSafeArea: bottomSafeArea,
    );

    return Material(
      key: const Key('mini_player_host'),
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Animated Bin Drop Target at bottom center during active drag
          if (controller.isDragging) ...[
            _buildBinDismissTarget(context, screenSize, bottomSafeArea),
          ],

          // Player form widget — direct 60fps tracking when dragging, animated positioned when idle/snapping
          AnimatedPositioned(
            duration: controller.isDragging
                ? Duration.zero
                : _positionController.duration!,
            curve: Curves.easeOutCubic,
            left: activePosition.dx,
            top: activePosition.dy,
            width: controller.form == PlayerForm.bar
                ? (screenSize.width - 16.0)
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) => _handleLongPressStart(
                details,
                activePosition,
              ),
              onLongPressMoveUpdate: (details) => _handleDragUpdate(
                details,
                screenSize,
                topSafeArea,
                bottomSafeArea,
              ),
              onLongPressEnd: (details) => _handleDragEnd(
                details,
                screenSize,
                bottomSafeArea,
              ),
              onLongPressCancel: _handleDragCancel,
              onTap: () {
                HapticsService().lightImpact();
                _recordGestureEvent('tap_expand');
                ExpandedCockpitModal.show(context);
              },
              child: AnimatedBuilder(
                animation: Listenable.merge([_morphController, _dismissController]),
                builder: (context, child) {
                  final dismissFactor = 1.0 - _dismissController.value;
                  return Transform.scale(
                    scale: dragScale * dismissFactor,
                    child: Opacity(
                      opacity: (_isOverBin ? 0.7 : 1.0) * dismissFactor.clamp(0.0, 1.0),
                      child: _buildPlayerForm(context, controller, playerState),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldHide(
    BuildContext context,
    MiniPlayerController controller,
    PlayerState playerState,
  ) {
    // Suppress during splash or when onboarding is incomplete (REQ-P47-BUG-01)
    if (ref.watch(isSplashActiveProvider)) return true;
    final onboarding = ref.watch(onboardingStateProvider);
    if (!onboarding.hasCompletedOnboarding) return true;

    // Hide on desktop (DesktopTransportBar handles desktop layout).
    if (ResponsiveUtils.isDesktop(context)) return true;

    // Hide when modal bottom sheets are open (REQ-P44-MINI-02).
    final modalSheetCount = ref.watch(modalSheetOpenCountProvider);
    if (modalSheetCount > 0) return true;

    // Hide when no active track or track is placeholder / 'Unknown' (REQ-P44-MINI-01).
    if (!playerState.hasActiveTrack) return true;
    final track = playerState.currentTrack;
    if (track == null ||
        track.title.trim().isEmpty ||
        track.title.trim().toLowerCase() == 'unknown') {
      return true;
    }

    // Hide when Now Playing cockpit is open.
    if (controller.isNowPlayingOpen) return true;

    // Hide when software keyboard is open.
    final viewInsets = MediaQuery.of(context).viewInsets;
    if (viewInsets.bottom > 0) return true;

    // Safe route inspection: only hide if route exists AND is splash/onboarding/auth
    final route = ModalRoute.of(context);
    if (route != null) {
      final routeName = route.settings.name;
      if (routeName == '/onboarding' ||
          routeName == '/splash' ||
          routeName == '/auth') {
        return true;
      }
    }

    return false;
  }

  Widget _buildPlayerForm(
    BuildContext context,
    MiniPlayerController controller,
    PlayerState playerState,
  ) {
    final track = playerState.currentTrack;
    if (track == null) return const SizedBox.shrink();

    void openCockpit() {
      HapticsService().lightImpact();
      _recordGestureEvent('tap_expand');
      ExpandedCockpitModal.show(context);
    }

    switch (controller.form) {
      case PlayerForm.bar:
        return MobileMiniPlayer(
          key: const Key('mini_player_bar'),
          onExpand: openCockpit,
        );
      case PlayerForm.pill:
        return PillForm(
          key: const Key('mini_player_pill'),
          onExpand: openCockpit,
        );
    }
  }

  void _handleLongPressStart(
    LongPressStartDetails details,
    Offset currentPosition,
  ) {
    HapticsService().mediumImpact();
    _recordGestureEvent('hold_start');
    _grabOffset = details.globalPosition - currentPosition;
    ref
        .read(miniPlayerControllerProvider.notifier)
        .startDrag(currentPosition);
    _morphController.forward();
  }

  void _handleDragUpdate(
    LongPressMoveUpdateDetails details,
    Size screenSize,
    double topSafeArea,
    double bottomSafeArea,
  ) {
    final controller = ref.read(miniPlayerControllerProvider);
    final formWidth = controller.form == PlayerForm.bar
        ? (screenSize.width - 16.0)
        : 160.0;
    final formHeight = controller.form == PlayerForm.bar ? 64.0 : 48.0;

    final targetTopLeft = details.globalPosition - _grabOffset;
    final clampedX = targetTopLeft.dx.clamp(
      8.0,
      (screenSize.width - formWidth - 8.0).clamp(8.0, double.infinity),
    );
    final bottomDockHeight = 56.0 + bottomSafeArea;
    final clampedY = targetTopLeft.dy.clamp(
      topSafeArea + 8.0,
      (screenSize.height - formHeight - bottomDockHeight - 12.0)
          .clamp(topSafeArea + 8.0, double.infinity),
    );

    final newPos = Offset(clampedX, clampedY);
    ref.read(miniPlayerControllerProvider.notifier).updateDrag(newPos);

    // Collision check against bottom-center bin target
    const binSize = 64.0;
    final binCenterX = screenSize.width / 2;
    final binCenterY =
        screenSize.height - (56.0 + bottomSafeArea + 16.0 + (binSize / 2));
    final binCenter = Offset(binCenterX, binCenterY);

    final playerCenter =
        Offset(clampedX + formWidth / 2, clampedY + formHeight / 2);
    final dist = (playerCenter - binCenter).distance;
    final isOver = dist <= 64.0;

    if (isOver != _isOverBin) {
      setState(() => _isOverBin = isOver);
      if (isOver) {
        HapticsService().heavyImpact();
      } else {
        HapticsService().selectionClick();
      }
    }
  }

  Future<void> _handleDragEnd(
    LongPressEndDetails details,
    Size screenSize,
    double bottomSafeArea,
  ) async {
    if (_isOverBin) {
      // Drag-to-bin dismiss: kill player and reset controller
      HapticsService().heavyImpact();
      _recordGestureEvent('drag_bin_dismiss');
      await _dismissController.forward();
      ref.read(playerStateProvider.notifier).dismiss();
      ref.read(miniPlayerControllerProvider.notifier).endDrag(
            details.velocity.pixelsPerSecond,
            screenSize,
            dismissedInBin: true,
            bottomSafeArea: bottomSafeArea,
          );
      _dismissController.reset();
      if (mounted) setState(() => _isOverBin = false);
    } else {
      final shouldDismiss = ref
          .read(miniPlayerControllerProvider.notifier)
          .endDrag(
            details.velocity.pixelsPerSecond,
            screenSize,
            dismissedInBin: false,
            bottomSafeArea: bottomSafeArea,
          );
      if (shouldDismiss) {
        HapticsService().mediumImpact();
        await _dismissController.forward();
        ref.read(playerStateProvider.notifier).dismiss();
        _dismissController.reset();
        _recordGestureEvent('fling_dismiss');
      } else {
        _morphController.reverse();
      }
      if (mounted) setState(() => _isOverBin = false);
    }
  }

  void _handleDragCancel() {
    ref.read(miniPlayerControllerProvider.notifier).setDragging(false);
    _morphController.reverse();
    if (mounted) setState(() => _isOverBin = false);
  }

  Widget _buildBinDismissTarget(
    BuildContext context,
    Size screenSize,
    double bottomSafeArea,
  ) {
    const binSize = 64.0;
    final binLeft = (screenSize.width - binSize) / 2;
    final binTop =
        screenSize.height - (56.0 + bottomSafeArea + 16.0 + binSize);

    return Positioned(
      left: binLeft,
      top: binTop,
      width: binSize,
      height: binSize,
      child: AnimatedScale(
        scale: _isOverBin ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: _isOverBin
                ? AppColors.error
                : Colors.black.withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isOverBin
                  ? Colors.white
                  : AppColors.error.withValues(alpha: 0.6),
              width: _isOverBin ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isOverBin ? AppColors.error : Colors.black)
                    .withValues(alpha: 0.5),
                blurRadius: _isOverBin ? 24 : 12,
                spreadRadius: _isOverBin ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: PhosphorIcon(
              AppIcons.trash,
              color: Colors.white,
              size: _isOverBin ? 30 : 26,
            ),
          ),
        ),
      ),
    );
  }

  void _recordGestureEvent(String gestureType) {
    final analytics = AnalyticsService();
    analytics.record(PlayerGestureEvent(gestureType));
  }
}

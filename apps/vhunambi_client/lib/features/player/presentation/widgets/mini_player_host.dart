import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/services/analytics_service.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/player_state.dart';
import '../providers/mini_player_controller.dart';
import '../providers/player_provider.dart';
import 'card_form.dart';
import 'expanded_cockpit_modal.dart';
import 'mobile_mini_player.dart';
import 'pill_form.dart';

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
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    // Hide during desktop, no active track, auth/onboarding, keyboard, or Now Playing
    if (_shouldHide(context, controller, playerState)) {
      return const SizedBox.shrink();
    }

    // Scale feedback during hold gesture (1.03x).
    final dragScale = controller.isDragging ? kHoldGestureScale : 1.0;

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
          // Extreme zone highlights during drag
          if (controller.isDragging) ...[
            _buildExtremeZoneHighlight(context, controller),
          ],

          // Player form widget — animated positioned
          AnimatedPositioned(
            duration: _positionController.duration!,
            curve: Curves.easeOutCubic,
            left: activePosition.dx,
            top: activePosition.dy,
            width: controller.form == PlayerForm.bar
                ? (screenSize.width - 16.0)
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: _handleLongPressStart,
              onLongPressMoveUpdate: _handleDragUpdate,
              onLongPressEnd: (details) async {
                final shouldDismiss = ref
                    .read(miniPlayerControllerProvider.notifier)
                    .endDrag(details.velocity.pixelsPerSecond, screenSize);
                if (shouldDismiss) {
                  // Fling dismiss: stop playback and clear track
                  HapticsService().mediumImpact();
                  await _dismissController.forward();
                  ref.read(playerStateProvider.notifier).dismiss();
                  _recordGestureEvent('fling_dismiss');
                } else {
                  _morphController.reverse();
                }
              },
              onTap: () {
                HapticsService().lightImpact();
                _recordGestureEvent('tap_expand');
                ExpandedCockpitModal.show(context);
              },
              child: AnimatedBuilder(
                animation: _morphController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: dragScale,
                    child: _buildPlayerForm(context, controller, playerState),
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
    // Hide on desktop (DesktopTransportBar handles desktop layout).
    if (ResponsiveUtils.isDesktop(context)) return true;

    // Hide when no active track.
    if (!playerState.hasActiveTrack) return true;

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
      case PlayerForm.card:
        return CardForm(
          key: const Key('mini_player_card'),
          onExpand: openCockpit,
        );
      case PlayerForm.pill:
        return PillForm(
          key: const Key('mini_player_pill'),
          onExpand: openCockpit,
        );
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    HapticsService().mediumImpact();
    _recordGestureEvent('hold_start');
    ref
        .read(miniPlayerControllerProvider.notifier)
        .startDrag(details.globalPosition);
    _morphController.forward();
  }

  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    ref
        .read(miniPlayerControllerProvider.notifier)
        .updateDrag(details.globalPosition);
  }

  Widget _buildExtremeZoneHighlight(
    BuildContext context,
    MiniPlayerController controller,
  ) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.1),
        child: const Center(
          child: Text(
            'Drag to reposition',
            style: TextStyle(color: Colors.white),
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

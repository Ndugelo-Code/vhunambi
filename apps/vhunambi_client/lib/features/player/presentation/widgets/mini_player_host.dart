import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/services/analytics_service.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/player_state.dart';
import '../providers/mini_player_controller.dart';
import '../providers/player_provider.dart';
import 'card_form.dart';
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

    // Hide on desktop (DesktopTransportBar handles desktop layout).
    if (ResponsiveUtils.isDesktop(context)) {
      return const SizedBox.shrink();
    }

    // Hide during onboarding, splash, auth, or Now Playing.
    if (_shouldHide(context, controller)) {
      return const SizedBox.shrink();
    }

    // Hide when no active track.
    if (!playerState.hasActiveTrack) {
      return const SizedBox.shrink();
    }

    // Hide when keyboard is open.
    final viewInsets = MediaQuery.of(context).viewInsets;
    if (viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    // Scale feedback during hold gesture (1.03x).
    final dragScale = controller.isDragging ? kHoldGestureScale : 1.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Extreme zone highlights during drag.
          if (controller.isDragging) ...[
            _buildExtremeZoneHighlight(context, controller),
          ],

          // Player form widget — animated positioned.
          AnimatedPositioned(
            duration: _positionController.duration!,
            curve: Curves.easeOutCubic,
            left: controller.position.dx,
            top: controller.position.dy,
            width: controller.form == PlayerForm.bar ? screenSize.width : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: _handleLongPressStart,
              onLongPressMoveUpdate: _handleDragUpdate,
              onLongPressEnd: (details) async {
                final shouldDismiss = ref
                    .read(miniPlayerControllerProvider.notifier)
                    .endDrag(details.velocity.pixelsPerSecond, screenSize);
                if (shouldDismiss) {
                  // Fling dismiss: stop playback and clear track.
                  HapticsService().mediumImpact();
                  await _dismissController.forward();
                  ref.read(playerStateProvider.notifier).dismiss();
                  _recordGestureEvent('fling_dismiss');
                } else {
                  _morphController.reverse();
                }
              },
              onTap: () {
                _recordGestureEvent('tap_expand');
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

  bool _shouldHide(BuildContext context, MiniPlayerController controller) {
    final route = ModalRoute.of(context);
    if (route == null) return true;

    final routeName = route.settings.name;
    return routeName == '/onboarding' ||
        routeName == '/splash' ||
        routeName == '/auth' ||
        controller.isNowPlayingOpen;
  }

  Widget _buildPlayerForm(
    BuildContext context,
    MiniPlayerController controller,
    PlayerState playerState,
  ) {
    final track = playerState.currentTrack;
    if (track == null) return const SizedBox.shrink();

    switch (controller.form) {
      case PlayerForm.bar:
        return MobileMiniPlayer(
          onExpand: () {
            _recordFormChange(controller, PlayerForm.bar);
          },
        );
      case PlayerForm.card:
        return CardForm(
          onExpand: () {
            _recordFormChange(controller, PlayerForm.card);
          },
        );
      case PlayerForm.pill:
        return PillForm(
          onExpand: () {
            _recordFormChange(controller, PlayerForm.pill);
          },
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

  void _recordFormChange(
    MiniPlayerController controller,
    PlayerForm newForm,
  ) {
    final oldFormName = controller.form.toString().split('.').last;
    final newFormName = newForm.toString().split('.').last;
    if (oldFormName != newFormName) {
      ref.read(miniPlayerControllerProvider.notifier).setForm(newForm);
      final analytics = AnalyticsService();
      analytics.record(PlayerFormChangedEvent(oldFormName, newFormName));
    }
  }

  void _recordGestureEvent(String gestureType) {
    final analytics = AnalyticsService();
    analytics.record(PlayerGestureEvent(gestureType));
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
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/profile_navigation_helper.dart';
import '../../../explore/domain/models/social_music_post.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../explore/presentation/views/kinetic_post_focus_view.dart';
import '../../../home/presentation/widgets/subscription_upgrade_modal.dart';
import '../../../profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import '../../../social/presentation/providers/social_feed_provider.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../widgets/notification_detail_bottom_sheet.dart';

/// Deterministic deep-link router for notification cards & CTAs
/// (`REQ-P67-ROUTE-01..02`).
abstract final class NotificationDeepLinkRouter {
  /// Primary entry point when a user taps a notification card.
  /// Opens [NotificationDetailBottomSheet] for milestone/informational alerts
  /// or routes directly when targeting a specific media/entity screen.
  static Future<void> handleCardTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (notification.opensDetailSheetFirst) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }
    await navigateDirect(context, ref, notification);
  }

  /// Executes direct navigation for [notification.effectiveRoute], falling back
  /// to [NotificationDetailBottomSheet] so zero taps are silent no-ops.
  static Future<void> navigateDirect(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final route = notification.effectiveRoute;
    if (route == null || route.isEmpty) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }

    if (route == '/studio') {
      ref.read(appNavigationTabProvider.notifier).state = 2;
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    if (route == '/creator-dna') {
      await CreatorDnaHelixLabSheet.show(context);
      return;
    }

    if (route == '/wallet') {
      await SubscriptionUpgradeModal.show(context);
      return;
    }

    if (route.startsWith('/track/')) {
      final trackId = route.substring('/track/'.length).trim();
      if (trackId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: trackId),
          ),
        );
        return;
      }
    }

    if (route.startsWith('/reel/')) {
      final clipId = route.substring('/reel/'.length).trim();
      final clips = ref.read(socialFeedProvider).clips;
      if (clips.isNotEmpty) {
        await KineticReelsModal.show(
          context,
          clips: clips,
          initialClipId: clipId.isEmpty ? null : clipId,
        );
        return;
      }
    }

    if (route.startsWith('/post/')) {
      final postId = route.substring('/post/'.length).trim();
      if (postId.isNotEmpty) {
        final posts = ref.read(socialFeedPostsProvider);
        SocialMusicPost? matched;
        for (final p in posts) {
          if (p.id == postId) {
            matched = p;
            break;
          }
        }
        await KineticPostFocusView.show(
          context,
          postId: postId,
          initialPost: matched,
        );
        return;
      }
    }

    if (route.startsWith('/creator/')) {
      final artistId = route.substring('/creator/'.length).trim();
      if (artistId.isNotEmpty) {
        await navigateToCreatorProfile(context, ref, creatorId: artistId);
        return;
      }
    }

    await NotificationDetailBottomSheet.show(context, notification);
  }
}

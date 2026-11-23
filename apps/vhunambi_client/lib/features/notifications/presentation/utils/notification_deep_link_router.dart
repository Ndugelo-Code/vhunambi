import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/navigation/profile_navigation_helper.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/licensing_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/license_certificate_sheet.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../widgets/notification_detail_bottom_sheet.dart';

/// Deterministic deep-link router for notification cards, Bell Popover & CTAs
/// (`EP-P67-DEEPLINK-ROUTER`, extended in `Phase 76` `EP-P76-DEEPLINK-COVERAGE`).
abstract final class NotificationDeepLinkRouter {
  /// Primary entry point when a user taps a notification card.
  /// Opens [NotificationDetailBottomSheet] for milestone/informational alerts
  /// or routes directly when targeting a specific media/entity screen.
  static Future<void> handleCardTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification, {
    NavigatorState? navigator,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final hostContext = _resolveHostContext(context, navigator);
    if (notification.opensDetailSheetFirst) {
      if (!hostContext.mounted) return;
      await NotificationDetailBottomSheet.show(hostContext, notification);
      return;
    }
    await navigateDirect(
      hostContext,
      ref,
      notification,
      navigator: navigator,
    );
  }

  /// Executes direct navigation for [notification.effectiveRoute], falling back
  /// to [NotificationDetailBottomSheet] so zero taps are silent no-ops.
  static Future<void> navigateDirect(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification, {
    NavigatorState? navigator,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final nav = navigator ?? Navigator.of(context);
    final hostContext = _resolveHostContext(context, nav);
    final route = notification.effectiveRoute?.trim();
    if (route == null || route.isEmpty) {
      if (hostContext.mounted) {
        await NotificationDetailBottomSheet.show(hostContext, notification);
      }
      return;
    }

    // 1. Core RootShell tab destinations
    final tabDestination = _resolveShellTabIndex(route);
    if (tabDestination != null) {
      ref.read(appNavigationTabProvider.notifier).state = tabDestination;
      nav.popUntil((r) => r.isFirst);
      return;
    }

    // 2. Creator DNA & Wallet modals
    if (route == '/creator-dna') {
      if (hostContext.mounted) {
        await CreatorDnaHelixLabSheet.show(hostContext);
      }
      return;
    }
    if (route == '/wallet') {
      if (hostContext.mounted) {
        await SubscriptionUpgradeModal.show(hostContext);
      }
      return;
    }

    // 3. Track Cockpit
    if (route.startsWith('/track/')) {
      final trackId = route.substring('/track/'.length).trim();
      if (trackId.isNotEmpty) {
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: trackId),
          ),
        );
        return;
      }
    }

    // 4. Kinetic Reels (with cold-start hydration + metadata fallback, REQ-P76-DL-02)
    if (route.startsWith('/reel/')) {
      final clipId = route.substring('/reel/'.length).trim();
      var clips = ref.read(socialFeedProvider).clips;
      if (clips.isEmpty) {
        await ref.read(socialFeedProvider.notifier).refreshFeed();
        if (!hostContext.mounted) return;
        clips = ref.read(socialFeedProvider).clips;
      }
      if (clips.isEmpty && clipId.isNotEmpty) {
        clips = <PublishedClip>[
          _buildFallbackReelClip(clipId, notification),
        ];
      }
      if (clips.isNotEmpty && hostContext.mounted) {
        await KineticReelsModal.show(
          hostContext,
          clips: clips,
          initialClipId: clipId.isEmpty ? null : clipId,
        );
        return;
      }
    }

    // 5. Kinetic Post Focus
    if (route.startsWith('/post/')) {
      final postId = route.substring('/post/'.length).trim();
      if (postId.isNotEmpty && hostContext.mounted) {
        final posts = ref.read(socialFeedPostsProvider);
        SocialMusicPost? matched;
        for (final p in posts) {
          if (p.id == postId) {
            matched = p;
            break;
          }
        }
        await KineticPostFocusView.show(
          hostContext,
          postId: postId,
          initialPost: matched,
        );
        return;
      }
    }

    // 6. Cryptographic License Certificates (/license/:id, /certificate/:id)
    if (route.startsWith('/license/') || route.startsWith('/certificate/')) {
      final certId = route.startsWith('/license/')
          ? route.substring('/license/'.length).trim()
          : route.substring('/certificate/'.length).trim();
      if (certId.isNotEmpty && hostContext.mounted) {
        final cert = _findLicenseCertificate(ref, certId, notification);
        if (cert != null) {
          await showLicenseCertificateSheet(hostContext, certificate: cert);
          return;
        }
        final track = _findLicensedLibraryTrack(ref, certId, notification);
        if (track != null) {
          await showLicenseCertificateSheet(hostContext, track: track);
          return;
        }
        ref.read(appNavigationTabProvider.notifier).state = 3;
        nav.popUntil((r) => r.isFirst);
        return;
      }
    }

    // 7. Profiles (/profile, /profile/:id, /creator/:id, /@:handle)
    if (route == '/profile' && hostContext.mounted) {
      final activeCreatorId = ref.read(currentCreatorIdProvider);
      await navigateToCreatorProfile(
        hostContext,
        ref,
        creatorId: activeCreatorId,
      );
      return;
    }

    if (route.startsWith('/profile/') && hostContext.mounted) {
      final creatorId = route.substring('/profile/'.length).trim();
      if (creatorId.isNotEmpty) {
        await navigateToCreatorProfile(
          hostContext,
          ref,
          creatorId: creatorId,
        );
        return;
      }
    }

    if (route.startsWith('/creator/') && hostContext.mounted) {
      final artistId = route.substring('/creator/'.length).trim();
      if (artistId.isNotEmpty) {
        await navigateToCreatorProfile(
          hostContext,
          ref,
          creatorId: artistId,
        );
        return;
      }
    }

    if (route.startsWith('/@') && hostContext.mounted) {
      final rawHandle = route.substring('/@'.length).trim();
      if (rawHandle.isNotEmpty) {
        final normalizedHandle = rawHandle.startsWith('@')
            ? rawHandle
            : '@$rawHandle';
        await navigateToCreatorProfile(
          hostContext,
          ref,
          creatorId: canonicalizeCreatorId(rawHandle),
          creatorHandle: normalizedHandle,
        );
        return;
      }
    }

    if (hostContext.mounted) {
      await NotificationDetailBottomSheet.show(hostContext, notification);
    }
  }

  static BuildContext _resolveHostContext(
    BuildContext context,
    NavigatorState? navigator,
  ) {
    if (context.mounted) return context;
    final overlayContext = navigator?.overlay?.context;
    if (overlayContext != null && overlayContext.mounted) {
      return overlayContext;
    }
    return context;
  }

  static int? _resolveShellTabIndex(String route) {
    return switch (route) {
      '/home' => 0,
      '/explore' => 1,
      '/studio' => 2,
      '/library' || '/vault' || '/licenses' => 3,
      '/marketplace' || '/market' => 4,
      _ => null,
    };
  }

  static SovereignLicenseCertificate? _findLicenseCertificate(
    WidgetRef ref,
    String certId,
    NotificationEntity notification,
  ) {
    final certs = ref.read(licenseCertificatesProvider);
    final metaCertId = (notification.metadata['certificateId'] as String?)
        ?.trim();
    final metaVaultTrackId = (notification.metadata['vaultTrackId'] as String?)
        ?.trim();
    for (final c in certs) {
      if (c.certificateId == certId ||
          (metaCertId != null && c.certificateId == metaCertId) ||
          c.vaultTrackId == certId ||
          c.beatId == certId ||
          (metaVaultTrackId != null && c.vaultTrackId == metaVaultTrackId)) {
        return c;
      }
    }
    return null;
  }

  static LibraryTrack? _findLicensedLibraryTrack(
    WidgetRef ref,
    String certId,
    NotificationEntity notification,
  ) {
    final tracks = ref.read(libraryTracksProvider);
    final metaVaultTrackId = (notification.metadata['vaultTrackId'] as String?)
        ?.trim();
    for (final t in tracks) {
      if (t.licenseCertificateIdOverride == certId ||
          t.licenseCertificateId == certId ||
          t.id == certId ||
          (metaVaultTrackId != null && t.id == metaVaultTrackId)) {
        return t;
      }
    }
    return null;
  }

  static PublishedClip _buildFallbackReelClip(
    String clipId,
    NotificationEntity notification,
  ) {
    final meta = notification.metadata;
    final creatorId = (meta['creatorId'] as String?)?.trim();
    final resolvedCreatorId = (creatorId != null && creatorId.isNotEmpty)
        ? creatorId
        : 'creator_vhunambi';
    final rawUsername =
        (meta['creatorUsername'] as String?)?.trim() ??
        (meta['creatorHandle'] as String?)?.trim().replaceFirst('@', '');
    final resolvedUsername = (rawUsername != null && rawUsername.isNotEmpty)
        ? rawUsername
        : extractRawCreatorId(resolvedCreatorId);
    final displayName = (meta['creatorName'] as String?)?.trim();
    final resolvedDisplayName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : 'Vhunambi Creator';
    final rawTitle = (meta['title'] as String?)?.trim();
    final resolvedTitle = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : notification.title;
    final rawGenre = (meta['genre'] as String?)?.trim();
    final resolvedGenre = (rawGenre != null && rawGenre.isNotEmpty)
        ? rawGenre
        : 'Amapiano';
    final trackId = (meta['trackId'] as String?)?.trim() ?? clipId;
    final language = (meta['language'] as String?)?.trim() ?? 'Tshivenḓa';

    return PublishedClip(
      id: clipId,
      trackId: trackId,
      creatorId: resolvedCreatorId,
      creatorUsername: resolvedUsername,
      creatorDisplayName: resolvedDisplayName,
      title: resolvedTitle,
      caption: notification.message,
      genre: resolvedGenre,
      audioUrl: (meta['audioUrl'] as String?) ?? '',
      coverUrl: (meta['coverUrl'] as String?) ?? '',
      videoUrl: meta['videoUrl'] as String?,
      dna: SongMetadataDna.fromTrackInfo(
        id: trackId,
        title: resolvedTitle,
        genre: resolvedGenre,
        language: language,
        durationSec: 180,
      ),
      publishedAt: notification.createdAt,
    );
  }
}

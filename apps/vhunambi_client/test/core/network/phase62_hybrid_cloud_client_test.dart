import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/content_studio/data/services/cloud_video_export_service.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/features/studio/data/services/generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/lyrics_review_provider.dart';

void main() {
  group('Phase 62 M62.7: Hybrid Cloud Origin, WS & Media URL Normalization', () {
    test('normalizeOriginUrl strips trailing slashes, /v1, and /api suffixes', () {
      expect(
        AppConstants.normalizeOriginUrl('https://vhunambi-api.prod.workers.dev/v1/'),
        equals('https://vhunambi-api.prod.workers.dev'),
      );
      expect(
        AppConstants.normalizeOriginUrl('https://vhunambi-api.prod.workers.dev/api'),
        equals('https://vhunambi-api.prod.workers.dev'),
      );
      expect(
        AppConstants.normalizeOriginUrl('https://vhunambi-api.prod.workers.dev/api/v1/'),
        equals('https://vhunambi-api.prod.workers.dev'),
      );
    });

    test('resolveWsUrl converts https:// to wss:// and http:// to ws://', () {
      expect(
        AppConstants.resolveWsUrl(
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev/v1',
        ),
        equals('wss://vhunambi-api.prod.workers.dev/ws/generation'),
      );
      expect(
        AppConstants.resolveWsUrl(overrideOrigin: 'http://localhost:3000'),
        equals('ws://localhost:3000/ws/generation'),
      );
    });

    test('normalizeCloudMediaUrl rewrites legacy r2/cdn/mock-storage URLs', () {
      expect(
        AppConstants.normalizeCloudMediaUrl(
          'https://r2.vhunambi.com/beats/kabza_1.wav',
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev',
        ),
        equals('https://vhunambi-api.prod.workers.dev/r2/beats/kabza_1.wav'),
      );
      expect(
        AppConstants.normalizeCloudMediaUrl(
          '/mock-storage/vox_amapiano_01.mp3',
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev',
        ),
        equals('https://vhunambi-api.prod.workers.dev/r2/vox_amapiano_01.mp3'),
      );
      expect(
        AppConstants.normalizeCloudMediaUrl(
          'https://cdn.vhunambi.za/reels/clip_01.mp4',
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev',
        ),
        equals('https://vhunambi-api.prod.workers.dev/r2/reels/clip_01.mp4'),
      );
    });

    test('canonicalizeCreatorId unifies @blackcoffee and creator_blackcoffee', () {
      expect(
        CreatorIdUtils.canonicalizeCreatorId('creator_blackcoffee'),
        equals('creator_black_coffee'),
      );
      expect(
        CreatorIdUtils.canonicalizeCreatorId('@blackcoffee'),
        equals('creator_black_coffee'),
      );
      expect(
        canonicalizeCreatorId('creator_blackcoffee'),
        equals('creator_black_coffee'),
      );
      expect(
        CreatorIdUtils.handleFromCreatorId('creator_black_coffee'),
        equals('@blackcoffee'),
      );
      expect(
        AuthSessionNotifier.seededStudioCreators['blackcoffee']?.creatorId,
        equals('creator_black_coffee'),
      );
      expect(
        AuthSessionNotifier.seededStudioCreators['black_coffee']?.creatorId,
        equals('creator_black_coffee'),
      );
    });

    test('preserves Phase 60 Hive box keys, layout constants, and service resolvers', () {
      expect(AppConstants.tokenBoxKey, equals('vhunambi_tokens'));
      expect(AppConstants.prefsBoxKey, equals('vhunambi_prefs'));
      expect(AppConstants.mobileMaxWidth, equals(767));
      expect(AppConstants.apiBaseUrl, endsWith('/v1'));
      expect(AppConstants.apiRestBaseUrl, endsWith('/api'));
      expect(GenerationSocketService.wsBaseUrl, endsWith('/ws/generation'));
      expect(CloudVideoExportService().baseUrl, isNotEmpty);
      expect(EdgeSyncCoordinator.resolveDefaultBaseUrl(), isNotEmpty);
    });

    test('Explore, Generation, Lyrics & Domain providers initialize cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(exploreRepositoryProvider), isNotNull);
      expect(container.read(generationSubmissionServiceProvider), isNotNull);
      expect(container.read(lyricsGenerationServiceProvider), isNotNull);
      expect(container.read(librarySyncRepositoryProvider), isNotNull);
      expect(container.read(marketplaceRepositoryProvider), isNotNull);
      expect(container.read(playlistRepositoryProvider), isNotNull);
      expect(container.read(socialRepositoryProvider), isNotNull);
    });
  });
}


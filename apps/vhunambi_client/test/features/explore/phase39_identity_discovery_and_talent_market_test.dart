import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/domain/services/discovery_hierarchy_ranker.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/views/marketplace_view.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_banner_header.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  group('Phase 39: Creator Identity, Discovery Hierarchy & Multi-Talent Market', () {
    const testTrack = Track(
      id: 'track_phase39_01',
      title: 'Durban Kwaito Summer Master',
      creatorName: 'DJ Vibe',
      creatorHandle: '@djvibe',
      genre: 'Kwaito',
      duration: Duration(minutes: 4, seconds: 10),
      audioUrl: 'https://cdn.vhunambi.com/audio/kwaito.mp3',
      provenanceType: AudioProvenanceType.humanDawMaster,
    );

    // =========================================================================
    // TRACK B: CREATOR IDENTITY ARCHETYPES & AUDIO PROVENANCE
    // =========================================================================
    test('REQ-ID-ARCH-01: CreatorIdentityArchetype has 5 distinct crafts', () {
      expect(CreatorIdentityArchetype.values.length, 5);
      expect(
        CreatorIdentityArchetype.values,
        containsAll([
          CreatorIdentityArchetype.dawProducer,
          CreatorIdentityArchetype.naturalVocalist,
          CreatorIdentityArchetype.liveInstrumentalist,
          CreatorIdentityArchetype.kineticPerformer,
          CreatorIdentityArchetype.aiSonicArchitect,
        ]),
      );
      expect(CreatorIdentityArchetype.dawProducer.displayName, 'DAW Producer');
      expect(CreatorIdentityArchetype.naturalVocalist.displayName, 'Natural Vocalist');
      expect(CreatorIdentityArchetype.liveInstrumentalist.displayName, 'Live Instrumentalist');
      expect(CreatorIdentityArchetype.kineticPerformer.displayName, 'Kinetic Performer');
      expect(CreatorIdentityArchetype.aiSonicArchitect.displayName, 'AI Sonic Architect');
    });

    test('REQ-ID-PROV-01: AudioProvenanceType declares authentic origin', () {
      expect(AudioProvenanceType.values.length, 5);
      expect(AudioProvenanceType.humanDawMaster.displayName, 'Human DAW Master');
      expect(AudioProvenanceType.liveVocalRecording.displayName, '100% Live Vocal');
      expect(AudioProvenanceType.liveInstrumentStem.displayName, 'Live Instrument');
      expect(AudioProvenanceType.hybridCoCreation.displayName, 'Hybrid Co-Creation');
      expect(AudioProvenanceType.aiGenerated.displayName, 'Vhunambi AI');
    });

    test('REQ-ID-ARCH-02: ArtistProfileEntity default values preserve backwards compatibility', () {
      const profile = ArtistProfileEntity(
        id: 'creator_01',
        username: 'test_creator',
        displayName: 'Test Creator',
        monogram: 'TC',
      );
      expect(profile.archetype, CreatorIdentityArchetype.aiSonicArchitect);
      expect(profile.monthlyListenersCount, 14200);

      final json = profile.toJson();
      expect(json['archetype'], 'aiSonicArchitect');
      expect(json['monthlyListenersCount'], 14200);

      final roundtrip = ArtistProfileEntity.fromJson(json);
      expect(roundtrip.archetype, CreatorIdentityArchetype.aiSonicArchitect);
      expect(roundtrip.monthlyListenersCount, 14200);
    });

    testWidgets('REQ-ID-ARCH-02: Profile displays Archetype Badge and Monthly Listeners Pill', (tester) async {
      const profile = ArtistProfileEntity(
        id: 'artist_01',
        username: 'ndugelo',
        displayName: 'Ndugelo',
        monogram: 'ND',
        archetype: CreatorIdentityArchetype.liveInstrumentalist,
        monthlyListenersCount: 28500,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ProfileBannerHeader(
              profile: profile,
              onToggleFollow: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('creator_archetype_badge')), findsOneWidget);
      expect(find.text('Live Instrumentalist'), findsOneWidget);
      expect(find.byKey(const Key('creator_monthly_listeners_pill')), findsOneWidget);
      expect(find.text('28.5K Monthly'), findsOneWidget);
    });

    testWidgets('REQ-ID-PROV-02: ExploreSocialPostCard renders Provenance Badge', (tester) async {
      final post = SocialMusicPost(
        id: 'post_prov_01',
        creatorId: 'c1',
        creatorName: 'DJ Vibe',
        creatorHandle: '@djvibe',
        publishedAt: DateTime.now(),
        caption: 'Late night master exported from Ableton!',
        track: testTrack,
        provenanceType: AudioProvenanceType.humanDawMaster,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExploreSocialPostCard(post: post),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Key('post_provenance_badge_${post.id}')), findsOneWidget);
      expect(find.text('Human DAW Master'), findsOneWidget);
    });

    testWidgets('REQ-UPL-01: DirectDawVocalUploadSheet mounts and renders 3 workflows', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DirectDawVocalUploadSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Direct DAW & Vocal Uploader'), findsOneWidget);
      expect(find.text('DAW Master'), findsOneWidget);
      expect(find.text('Vocal / Stem'), findsOneWidget);
      expect(find.text('Dance Reel'), findsOneWidget);
      expect(find.byKey(const Key('direct_upload_submit_btn')), findsOneWidget);
    });

    // =========================================================================
    // TRACK C: 3-STAGE DISCOVERY HIERARCHY
    // =========================================================================
    test('REQ-DISC-RANK-01: DiscoveryHierarchyRanker categorizes posts into tiers', () {
      final hitPost = SocialMusicPost(
        id: 'hit_01',
        creatorId: 'c1',
        creatorName: 'Makhadzi',
        creatorHandle: '@makhadzi',
        isCreatorVerified: true,
        publishedAt: DateTime.now(),
        caption: 'Viral Amapiano anthem!',
        track: const Track(
          id: 't_hit',
          title: 'Polokwane Sunset',
          creatorName: 'Makhadzi',
          genre: 'Amapiano',
          duration: Duration(minutes: 3),
          playCount: 150,
        ),
        likeCount: 120,
        remixCount: 15,
        repostCount: 10,
        isFollowingCreator: true,
        provenanceType: AudioProvenanceType.liveVocalRecording,
      );

      final rankHit = DiscoveryHierarchyRanker.rank(hitPost);
      expect(rankHit.tier, DiscoveryStageTier.mainstage);
      expect(rankHit.score, greaterThanOrEqualTo(45.0));

      final freshPost = SocialMusicPost(
        id: 'fresh_01',
        creatorId: 'c2',
        creatorName: 'New Producer',
        creatorHandle: '@newbie',
        publishedAt: DateTime.now(),
        caption: 'First beat dropped',
        track: const Track(
          id: 't_fresh',
          title: 'Rough Idea',
          creatorName: 'Newbie',
          genre: 'Gqom',
          duration: Duration(minutes: 2),
          playCount: 2,
        ),
        likeCount: 1,
        remixCount: 0,
        repostCount: 0,
        provenanceType: AudioProvenanceType.aiGenerated,
      );

      final rankFresh = DiscoveryHierarchyRanker.rank(freshPost);
      expect(rankFresh.tier, DiscoveryStageTier.freshCrate);
    });

    testWidgets('REQ-DISC-UI-01: ExploreView mounts explore_stage_tier_selector', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ExploreView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_stage_tier_selector')), findsOneWidget);
      expect(find.text('Mainstage'), findsOneWidget);
      expect(find.text('Rising Breakout'), findsOneWidget);
      expect(find.text('Fresh Crate'), findsOneWidget);
    });

    // =========================================================================
    // TRACK D: 4-PILLAR MULTI-TALENT MARKETPLACE
    // =========================================================================
    test('REQ-MKT-CAT-01: MarketplaceAssetCategory covers all 4 talent pillars', () {
      expect(MarketplaceAssetCategory.values.length, 5);
      expect(
        MarketplaceAssetCategory.values,
        containsAll([
          MarketplaceAssetCategory.all,
          MarketplaceAssetCategory.beats,
          MarketplaceAssetCategory.vocals,
          MarketplaceAssetCategory.liveInstruments,
          MarketplaceAssetCategory.voiceDnaAndPacks,
        ]),
      );
    });

    test('REQ-MKT-FILTER-01: filterBeats filters listings by asset category', () {
      final now = DateTime.now();
      final beatsList = [
        BeatListingEntity(
          id: 'b1',
          title: 'Township Beat',
          producerId: 'p1',
          producerName: 'Sipho',
          producerHandle: '@sipho',
          genre: 'Amapiano',
          bpm: 112,
          musicalKey: 'F# Minor',
          priceInCredits: 5,
          previewAudioUrl: 'url',
          createdAt: now,
          assetCategory: MarketplaceAssetCategory.beats,
        ),
        BeatListingEntity(
          id: 'v1',
          title: 'Tshivenḓa Vocal Hook',
          producerId: 'p2',
          producerName: 'Makhadzi',
          producerHandle: '@makhadzi',
          genre: 'Amapiano',
          bpm: 112,
          musicalKey: 'F# Minor',
          priceInCredits: 4,
          previewAudioUrl: 'url',
          createdAt: now,
          assetCategory: MarketplaceAssetCategory.vocals,
          provenanceType: AudioProvenanceType.liveVocalRecording,
        ),
      ];

      // 1. All categories
      final allFiltered = filterBeats(
        beats: beatsList,
        filter: const MarketplaceFilterState(category: MarketplaceAssetCategory.all),
      );
      expect(allFiltered.length, 2);

      // 2. Filter vocals only
      final vocalsOnly = filterBeats(
        beats: beatsList,
        filter: const MarketplaceFilterState(category: MarketplaceAssetCategory.vocals),
      );
      expect(vocalsOnly.length, 1);
      expect(vocalsOnly.first.id, 'v1');
    });

    testWidgets('REQ-MKT-UI-01: MarketplaceView mounts category tabs for all pillars', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MarketplaceView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final cat in MarketplaceAssetCategory.values) {
        expect(find.byKey(Key('market_category_tab_${cat.name}')), findsOneWidget);
      }
    });

    testWidgets('REQ-MKT-ROYALTY-01: licenseBeat credits buyer vault and splits 85% creator royalties', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final initialWalletZar =
          capturedRef.read(creatorWalletProvider).creatorEarnedZar;

      final testListing = BeatListingEntity(
        id: 'license_test_01',
        title: 'isiZulu Vocal Cry',
        producerId: 'creator_sigwa',
        producerName: 'Sigwa Inaf',
        producerHandle: '@sigwa_inaf',
        genre: 'Maskandi',
        bpm: 115,
        musicalKey: 'C Major',
        priceInCredits: 6,
        previewAudioUrl: 'https://cdn.vhunambi.com/audio/sigwa.mp3',
        createdAt: DateTime.now(),
        assetCategory: MarketplaceAssetCategory.vocals,
        provenanceType: AudioProvenanceType.liveVocalRecording,
      );

      final outcome = licenseBeat(capturedRef, testListing);
      expect(outcome, BeatLicenseOutcome.licensed);

      // Buyer Vault received track
      final libraryTracks = capturedRef.read(libraryTracksProvider);
      expect(libraryTracks.any((t) => t.id == 'market_license_test_01'), isTrue);

      // Creator received 85% royalties
      final updatedWalletZar =
          capturedRef.read(creatorWalletProvider).creatorEarnedZar;
      expect(updatedWalletZar, greaterThan(initialWalletZar));
    });
  });
}


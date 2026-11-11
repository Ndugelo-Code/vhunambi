import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/cache/profile_cache.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/design_system/models/generation_request_notifier.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/data/repositories/http_marketplace_repository.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/mastering/domain/models/stem_mastering_recipe.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/stem_remix_provider.dart';
import 'package:vhunambi_client/features/sound_signature/data/sound_signature_repository.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/phonetic_articulation_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/pitch_contour_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/recording_quality_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/rhythmic_transient_grid.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_signature_dna.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/timbre_identity_profile.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

SoundSignatureDna _sampleSoundSignature(String id) {
  return SoundSignatureDna(
    id: id,
    displayCode: SoundSignatureDna.generateDisplayCode(id),
    source: SignatureSource.live,
    createdAtIso: '2026-11-09T12:00:00.000Z',
    durationSec: 12.5,
    identity: TimbreIdentityProfile(
      cepstralDescriptor: List<double>.generate(16, (i) => math.sin(i * 0.3) * 0.5),
      formantsHz: const [660.0, 1180.0, 2400.0, 3550.0],
      glottalWarmth: 0.80,
      harmonicPurityRatio: 0.86,
    ),
    pitch: PitchContourProfile(
      f0CentsMidi: List<int>.filled(64, 6000),
      rootPitchClass: 9,
      scaleMode: AfricanScaleMode.minorPentatonic,
      keyConfidence: 0.91,
      stabilityScore: 0.85,
      naturalVibratoHz: 5.1,
      naturalVibratoDepthCents: 24.0,
    ),
    articulation: const PhoneticArticulationProfile(
      consonantTransientSharpness: 0.88,
      protectedSegments: [TimeSpanMs(100, 220)],
    ),
    rhythm: const RhythmicTransientGrid(
      onsetMs: [100, 500],
      offsetFromGridMs: [0, 4],
      quantizedNotes: [
        MelodyStepNote(stepIndex: 0, scaleRow: 2, velocity: 0.9),
      ],
    ),
    quality: const RecordingQualityProfile(
      snrDb: 26.0,
      clippingPct: 0.0,
      bandwidthHz: 18000.0,
      loudnessLufs: -16.0,
      reverbEdtMs: 90.0,
      voicedRatio: 0.82,
    ),
  );
}

void main() {
  group('Phase 60 M60.2-M60.4: Cold-Start Persistence Across All 10 Ignored Domains', () {
    late Directory tempDir;

    Future<void> restartHiveSession() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await Hive.close();
      SovereignDomainStorageMode.clearAllForTesting();
      SoundSignatureRepository.clearInMemoryForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      Hive.init(tempDir.path);
      await SovereignHiveBootstrapService.openAllBoxes();
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_domains_p60_');
      SovereignDomainStorageMode.clearAllForTesting();
      SoundSignatureRepository.clearInMemoryForTesting();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      Hive.init(tempDir.path);
      await SovereignHiveBootstrapService.openAllBoxes();
    });

    tearDown(() async {
      await Hive.close();
      SovereignDomainStorageMode.clearAllForTesting();
      SoundSignatureRepository.clearInMemoryForTesting();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('OnboardingNotifier hydrates across restarts & SplashView recognizes returning user', () async {
      final c1 = ProviderContainer();
      final onboarding1 = c1.read(onboardingStateProvider.notifier);
      onboarding1.setBirthYear(1996);
      onboarding1.setCulturalHeritage('Tshivenḓa');
      onboarding1.completeOnboarding();
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final restored = c2.read(onboardingStateProvider);
      expect(restored.hasCompletedOnboarding, isTrue);
      expect(restored.birthYear, 1996);
      expect(restored.culturalHeritage, 'Tshivenḓa');
    });

    testWidgets('SplashView stays fast and reads persisted onboarding completion without error', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        container.read(onboardingStateProvider.notifier).completeOnboarding();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });

      var finished = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SplashView(
              duration: const Duration(milliseconds: 40),
              onFinished: () => finished = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(finished, isTrue);
    });

    test('NotificationsNotifier read/add/delete survives restart', () async {
      final c1 = ProviderContainer();
      final notifier1 = c1.read(notificationsProvider.notifier);
      notifier1.addNotification(
        NotificationEntity(
          id: 'notif_p60_1',
          title: 'Hive Brain Online',
          message: 'All 26 boxes mounted cleanly.',
          category: NotificationCategory.system,
          createdAt: DateTime(2026, 11, 10, 1),
        ),
      );
      notifier1.addNotification(
        NotificationEntity(
          id: 'notif_p60_2',
          title: 'Second Alert',
          message: 'Will be deleted.',
          category: NotificationCategory.social,
          createdAt: DateTime(2026, 11, 10, 2),
        ),
      );
      notifier1.markAsRead('notif_p60_1');
      notifier1.deleteNotification('notif_p60_2');
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      await c2.read(notificationsProvider.notifier).hydrateFromStorage();
      final list = c2.read(notificationsProvider);
      expect(list.any((n) => n.id == 'notif_p60_1' && n.isRead), isTrue);
      expect(list.any((n) => n.id == 'notif_p60_2'), isFalse);
    });

    test('SoundSignatureRepository supports Hive persistence & L1 in-memory fallback', () async {
      const repo = SoundSignatureRepository();
      final dna = _sampleSoundSignature('01P60SIGDNA000000000000001');
      await repo.saveSignature(dna);

      // Clear L1 cache to prove read comes back from Hive disk box.
      SoundSignatureRepository.clearInMemoryForTesting();
      final fromHive = repo.getSignature(dna.id);
      expect(fromHive, isNotNull);
      expect(fromHive!.id, dna.id);
      expect(fromHive.displayCode, dna.displayCode);

      // Now close Hive and verify L1 in-memory fallback works with zero boxes open.
      await Hive.close();
      SoundSignatureRepository.clearInMemoryForTesting();
      final headlessDna = _sampleSoundSignature('01P60SIGDNA000000000000002');
      await repo.saveSignature(headlessDna);
      expect(repo.getSignature(headlessDna.id)?.id, headlessDna.id);
      expect(repo.getAllSignatures().map((s) => s.id), contains(headlessDna.id));
    });

    test('CreatorWalletNotifier persists balance, ledger & SA banking details across restart', () async {
      final c1 = ProviderContainer();
      final wallet1 = c1.read(creatorWalletProvider.notifier);
      wallet1.topUpCoins(150);
      await wallet1.savePayoutBankDetails(
        const CreatorBankingDetails(
          bankName: 'Capitec Bank',
          accountHolder: 'Ndugelo Studio',
          accountNumber: '1234567890',
          branchCode: '470010',
          payoutMethod: 'Capitec Pay',
          paymentRail: PayoutGatewayRail.capitecPay,
        ),
      );
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final restored = c2.read(creatorWalletProvider);
      expect(restored.userCoinsBalance, 400);
      expect(restored.savedBankDetails?.bankName, 'Capitec Bank');
      expect(restored.savedBankDetails?.accountNumber, '1234567890');
      expect(restored.savedBankDetails?.paymentRail, PayoutGatewayRail.capitecPay);
    });

    test('PlayerNotifier & RecentlyPlayedNotifier persist session and cold-start paused', () async {
      const trackA = Track(
        id: 'trk_p60_alpha',
        title: 'Makhado Morning',
        creatorName: 'Ndugelo',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 4, seconds: 10),
      );
      const trackB = Track(
        id: 'trk_p60_beta',
        title: 'Thohoyandou Night',
        creatorName: 'Makhadzi',
        genre: 'Afro House',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 3, seconds: 45),
      );

      final c1 = ProviderContainer();
      final player1 = c1.read(playerStateProvider.notifier);
      player1.playTrack(trackA, queue: const [trackA, trackB]);
      player1.seek(const Duration(seconds: 67));
      player1.toggleShuffle();
      player1.cycleRepeatMode();
      c1.read(recentlyPlayedIdsProvider.notifier).register('trk_p60_alpha');
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final restoredPlayer = c2.read(playerStateProvider);
      expect(restoredPlayer.currentTrack?.id, 'trk_p60_alpha');
      expect(restoredPlayer.queue.length, 2);
      expect(restoredPlayer.position.inSeconds, 67);
      expect(restoredPlayer.isShuffle, isTrue);
      expect(restoredPlayer.repeatMode, AudioRepeatMode.all);
      // Must NOT auto-blast audio on cold restart.
      expect(restoredPlayer.isPlaying, isFalse);

      final restoredRecent = c2.read(recentlyPlayedIdsProvider);
      expect(restoredRecent.first, 'trk_p60_alpha');
    });

    test('StemMixerNotifier & MasteringSessionNotifier persist DSP & mastering recipes', () async {
      // 1. Test StemMixerNotifier persistence & cold restart first.
      final c1 = ProviderContainer();
      c1.read(stemMixerProvider.notifier).setChannelGain(StemType.bass, 1.35);
      c1.read(stemMixerProvider.notifier).toggleMute(StemType.vocals);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final restoredStem = c2.read(stemMixerProvider);
      final bass = restoredStem.channels.firstWhere((c) => c.type == StemType.bass);
      final vocals = restoredStem.channels.firstWhere((c) => c.type == StemType.vocals);
      expect(bass.gain, closeTo(1.35, 0.001));
      expect(vocals.isMuted, isTrue);

      // 2. Test MasteringSessionNotifier persistence & cold restart separately so Tier A
      // preview coupling does not overwrite the StemMixer assertion above.
      final m1 = ProviderContainer();
      await Future<void>.delayed(Duration.zero);
      final master1 = m1.read(masteringSessionProvider.notifier);
      master1.setTargetLufs(-14.0);
      master1.setVocalFlavor(VocalCleanseFlavor.wideAnthem);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      m1.dispose();

      await restartHiveSession();

      final m2 = ProviderContainer();
      addTearDown(m2.dispose);
      final restoredMaster = m2.read(masteringSessionProvider);
      expect(restoredMaster.recipe.targetLufs, closeTo(-14.0, 0.01));
      expect(restoredMaster.recipe.vocals.flavor, VocalCleanseFlavor.wideAnthem);
    });

    test('HeritageCrate, MpcSlicer & MyceliumBiomeGraph persist across restart', () async {
      final c1 = ProviderContainer();
      final crateNotifier = c1.read(heritageCrateProvider.notifier);
      final sampleId = c1.read(heritageCrateProvider).allSamples.first.id;
      final beforeFav = c1.read(heritageCrateProvider).allSamples.first.isFavorite;
      crateNotifier.toggleFavorite(sampleId);

      final mpc1 = c1.read(mpcSlicerProvider.notifier);
      mpc1.setPitchShift(0, 5);
      mpc1.toggleReverse(0);

      c1.read(myceliumBiomeGraphProvider.notifier).addInstrumentLeaf(
            name: 'Venda Mbila Resonance',
            iconIdentifier: 'musicNotes',
          );
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final restoredSample = c2
          .read(heritageCrateProvider)
          .allSamples
          .firstWhere((s) => s.id == sampleId);
      expect(restoredSample.isFavorite, isNot(beforeFav));

      final restoredPad0 = c2.read(mpcSlicerProvider).pads.first;
      expect(restoredPad0.pitchShiftSemitones, 5);
      expect(restoredPad0.isReversed, isTrue);

      final harmonyLeaves = c2
              .read(myceliumBiomeGraphProvider)
              .clusters[MyceliumClusterDomain.harmonyNetwork]
              ?.childLeaves ??
          const [];
      expect(
        harmonyLeaves.any((leaf) => leaf.title == 'Venda Mbila Resonance'),
        isTrue,
      );
    });

    test('Explore, SocialReels, Comments, StemRemix, Marketplace, ContentStudio & Profile persist', () async {
      final c1 = ProviderContainer();

      // 1. Explore tracks, likes, co-signs, following, recent searches
      final exploreTrackId = c1.read(exploreTracksProvider).first.id;
      c1.read(exploreTracksProvider.notifier).toggleTrackLike(exploreTrackId);
      final firstPostId = c1.read(socialFeedPostsProvider).first.id;
      final initialCosigns = c1.read(coSignVotesProvider)[firstPostId] ?? 0;
      c1.read(socialFeedPostsProvider.notifier).cosignPost(firstPostId);
      c1.read(followingCreatorIdsProvider.notifier).toggleFollow('creator_ndugelo');
      c1.read(recentSearchesProvider.notifier).addQuery('Tshivenda Log Drum');

      // 2. Social reels + multi-tap loves + comments + stem remix context
      final clip = PublishedClip(
        id: 'clip_p60_1',
        trackId: 'trk_p60_clip',
        creatorId: 'creator_me',
        creatorUsername: 'ndugelo',
        creatorDisplayName: 'Ndugelo',
        title: 'Venda Bassline',
        genre: 'Amapiano',
        audioUrl: 'https://example.com/clip.mp3',
        coverUrl: 'https://example.com/cover.jpg',
        dna: SongMetadataDna.fromTrackInfo(
          id: 'dna_p60_1',
          title: 'Venda Bassline',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          durationSec: 45,
        ),
        publishedAt: DateTime(2026, 11, 10),
      );
      c1.read(socialFeedProvider.notifier).prependClip(clip);
      c1.read(socialFeedProvider.notifier).recordLove(clip.id);
      c1.read(socialFeedProvider.notifier).recordLove(clip.id);
      await c1.read(reelsCommentsProvider.notifier).addComment(
            clipId: clip.id,
            text: 'Bassline slaps!',
          );
      c1.read(stemRemixProvider.notifier).initiateRemix(clip);

      // 3. Marketplace exclusive buyout lock
      final beatId = c1.read(marketplaceBeatsProvider).first.id;
      c1.read(marketplaceBeatsProvider.notifier).markSoldExclusive(
            beatId: beatId,
            buyerId: 'buyer_sovereign',
          );
      final marketRepo = HttpMarketplaceRepository();
      await marketRepo.licenseBeat(
        beatId: beatId,
        buyerId: 'buyer_sovereign',
        tier: 'exclusive_stem',
      );

      // 4. Content Studio draft
      c1.read(contentStudioProvider.notifier).initializeWithDna(
            dna: clip.dna,
            audioUrl: clip.audioUrl,
            coverArtUrl: clip.coverUrl,
          );
      c1.read(contentStudioProvider.notifier).setPreset(
            LyricTypographyPreset.bantuCalligraphy,
          );
      c1.read(contentStudioProvider.notifier).toggleEffect(filmGrain: false);

      // 5. Owner 'me' profile customizations
      c1.read(ownerProfileProvider.notifier).updateProfileDetails(
            displayName: 'Ndugelo Sovereign',
            bio: 'Persisted across restarts',
          );
      c1.read(ownerProfileProvider.notifier).setPinnedTrack('trk_pin_99');

      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);

      // Assert Explore
      expect(
        c2.read(exploreTracksProvider.notifier).isTrackLiked(exploreTrackId),
        isTrue,
      );
      expect(c2.read(coSignVotesProvider)[firstPostId], initialCosigns + 1);
      expect(c2.read(followingCreatorIdsProvider).contains('creator_ndugelo'), isTrue);
      expect(c2.read(recentSearchesProvider).first, 'Tshivenda Log Drum');

      // Assert Social Reels + Comments + Remix
      final restoredClip = c2
          .read(socialFeedProvider)
          .clips
          .firstWhere((c) => c.id == 'clip_p60_1');
      expect(restoredClip.userReactionCount, 2);
      expect(restoredClip.isLikedByMe, isTrue);
      final restoredComments =
          c2.read(reelsCommentsProvider.notifier).commentsForClip('clip_p60_1');
      expect(restoredComments.any((c) => c.text == 'Bassline slaps!'), isTrue);
      expect(c2.read(stemRemixProvider)?.parentClipId, 'clip_p60_1');

      // Assert Marketplace exclusive lock
      final restoredBeat = c2
          .read(marketplaceBeatsProvider)
          .firstWhere((b) => b.id == beatId);
      expect(restoredBeat.isExclusiveSold, isTrue);
      expect(restoredBeat.exclusiveBuyerId, 'buyer_sovereign');

      // Assert Content Studio
      final restoredStudio = c2.read(contentStudioProvider);
      expect(restoredStudio.dna?.id, 'dna_p60_1');
      expect(
        restoredStudio.typographyPreset,
        LyricTypographyPreset.bantuCalligraphy,
      );
      expect(restoredStudio.effects.filmGrain, isFalse);

      // Assert Owner Profile 'me'
      final restoredOwner = c2.read(ownerProfileProvider);
      expect(restoredOwner.displayName, 'Ndugelo Sovereign');
      expect(restoredOwner.pinnedTrackId, 'trk_pin_99');
    });

    test('ProfileCache exempts profile_me from 20-entry LRU eviction', () async {
      final cache = ProfileCache();
      await cache.put(
        'me',
        ArtistProfileEntity(
          id: 'me',
          username: 'ndugelo',
          displayName: 'Pinned Owner',
          monogram: 'ND',
          bio: 'Must never evict',
        ),
      );

      for (var i = 0; i < 25; i++) {
        await cache.put(
          'ext_artist_$i',
          ArtistProfileEntity(
            id: 'ext_artist_$i',
            username: 'artist_$i',
            displayName: 'Artist $i',
            monogram: 'AR',
            bio: 'External artist $i',
          ),
        );
      }

      final meEntry = await cache.get('me');
      expect(meEntry, isNotNull);
      expect(meEntry!.data.displayName, 'Pinned Owner');

      final profileBox = Hive.box<dynamic>(AppConstants.profileBoxKey);
      final externalKeys = profileBox.keys
          .map((k) => k.toString())
          .where((k) => k.startsWith('profile_') && k != 'profile_me')
          .toList();
      expect(externalKeys.length, lessThanOrEqualTo(ProfileCache.maxCacheSize));
    });

    test('MiniPlayerController & GenerationRequestNotifier persist across restart (REQ-P60-DOM-08)', () async {
      final c1 = ProviderContainer();
      final mini1 = c1.read(miniPlayerControllerProvider.notifier);
      mini1.setForm(PlayerForm.pill);
      mini1.setMode(PlayerMode.manual);
      mini1.endDrag(
        const Offset(0, 0),
        const Size(400, 800),
      );

      final gen1 = c1.read(generationRequestProvider.notifier);
      await gen1.setGenre(Genre.gqom);
      await gen1.setBpm(136);
      await gen1.setVisibility('public');
      c1.dispose();

      await restartHiveSession();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final mini2 = c2.read(miniPlayerControllerProvider.notifier);
      await mini2.loadState();
      expect(mini2.form, PlayerForm.pill);
      expect(mini2.mode, PlayerMode.manual);

      final gen2 = c2.read(generationRequestProvider);
      expect(gen2.model.genre, Genre.gqom);
      expect(gen2.model.bpm, 136);
      expect(gen2.model.visibility, 'public');
    });
  });
}

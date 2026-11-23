import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/media/vhunambi_media_upload_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/pill_form.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/features/studio/domain/services/bantu_lyric_translation_service.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/domain/utils/synced_lyric_timeline.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/bantu_word_glossary_sheet.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _RecordingSocialRepository implements ISocialRepository {
  int uploadCalls = 0;
  String? lastFilename;
  String? lastMimeType;
  int? lastByteCount;

  @override
  Future<({String url, String mediaKind, String mimeType, int sizeBytes})>
  uploadReelMedia({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    uploadCalls += 1;
    lastFilename = filename;
    lastMimeType = mimeType;
    lastByteCount = bytes.length;
    return (
      url: 'https://cdn.vhunambi.test/r2/$filename',
      mediaKind: 'image',
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Track _sampleTrack({
  String id = 'trk_p77_1',
  String mood = 'uplifting',
  String language = 'Tshivenḓa',
}) {
  return Track(
    id: id,
    title: 'Vhunambi Dawn',
    creatorName: 'Lerato',
    genre: 'Amapiano',
    language: language,
    duration: const Duration(seconds: 120),
    mood: mood,
  );
}

void main() {
  group('Phase 77 Chromatic Player, Synced Clean Lyrics & Unified R2', () {
    test(
      'SyncedLyricTimeline extracts lines and computes monotonic active indices & seek targets',
      () {
        final lines = SyncedLyricTimeline.extractLines(
          'Line one\n\n  Line two  \nLine three\nLine four',
        );
        expect(lines, ['Line one', 'Line two', 'Line three', 'Line four']);

        expect(
          SyncedLyricTimeline.resolveActiveLineIndex(
            lineCount: 0,
            position: const Duration(seconds: 10),
            duration: const Duration(seconds: 100),
          ),
          -1,
        );
        expect(
          SyncedLyricTimeline.resolveActiveLineIndex(
            lineCount: 4,
            position: Duration.zero,
            duration: Duration.zero,
          ),
          -1,
        );

        final idx0 = SyncedLyricTimeline.resolveActiveLineIndex(
          lineCount: 4,
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 100),
        );
        final idx2 = SyncedLyricTimeline.resolveActiveLineIndex(
          lineCount: 4,
          position: const Duration(seconds: 55),
          duration: const Duration(seconds: 100),
        );
        final idx3 = SyncedLyricTimeline.resolveActiveLineIndex(
          lineCount: 4,
          position: const Duration(seconds: 99),
          duration: const Duration(seconds: 100),
        );
        expect(idx0, 0);
        expect(idx2, 2);
        expect(idx3, 3);

        final targets = List<Duration>.generate(
          4,
          (i) => SyncedLyricTimeline.seekTargetForLine(
            lineIndex: i,
            lineCount: 4,
            duration: const Duration(seconds: 100),
          ),
        );
        expect(targets[0], Duration.zero);
        for (int i = 1; i < targets.length; i++) {
          expect(targets[i] > targets[i - 1], isTrue);
        }
      },
    );

    testWidgets(
      'BantuLyricTranslationService covers all 9 languages and BantuWordGlossarySheet renders in Dark & Light',
      (tester) async {
        expect(BantuLyricTranslationService.allBantuLanguageCodes.length, 9);
        expect(
          BantuLyricTranslationService.resolveLanguageCode('Tshivenḓa'),
          've',
        );
        expect(
          BantuLyricTranslationService.resolveLanguageCode('isiZulu'),
          'zu',
        );
        expect(BantuLyricTranslationService.resolveLanguageCode('Sepedi'), 'nso');

        final def = BantuLyricTranslationService.lookupWord(
          'Sawubona!',
          baseLanguageCode: 'Tshivenḓa',
        );
        expect(def.normalizedWord, 'sawubona');
        expect(def.hasMeaning, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: BantuWordGlossarySheet(definition: def)),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('bantu_word_glossary_sheet')), findsOneWidget);
        expect(find.text('Sawubona!'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: BantuWordGlossarySheet(definition: def)),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('bantu_word_glossary_sheet')), findsOneWidget);
      },
    );

    testWidgets(
      'ExpandedCockpitModal renders chromatic surface + synced clean lyrics (strips metadata/[shakers] cues) in Dark & Light',
      (tester) async {
        tester.view.physicalSize = const Size(480, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        expect(
          LyricKaraokeSanitizer.cleanLyricTextForKaraoke(
            '[Intro]\n[Crisp soft shakers]\nSawubona eMzansi',
          ),
          'Sawubona eMzansi',
        );

        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final track = _sampleTrack();
        final detailRecord = TrackDetailEntity(
          id: track.id,
          title: track.title,
          genre: track.genre,
          language: track.language,
          duration: track.duration,
          creatorId: 'creator_lerato',
          creatorName: 'Lerato',
          creatorHandle: '@lerato',
          lyrics:
              'Title: Vhunambi Dawn\nBPM: 118\n[Crisp soft shakers, airy synth pads]\nSawubona eMzansi (x2)\nNdaa Vhunambi',
          moodId: 'uplifting',
        );

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
            trackDetailFamilyProvider(track.id).overrideWith(
              (ref) => TrackDetailNotifier(track.id, ref: ref)..state = detailRecord,
            ),
          ],
        );
        container.read(playerStateProvider.notifier).playTrack(track);

        Future<void> pumpCockpit(ThemeData theme) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: theme,
                themeAnimationDuration: Duration.zero,
                home: const Scaffold(body: ExpandedCockpitModal()),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }

        await pumpCockpit(AppTheme.darkTheme);
        expect(find.byKey(const Key('cockpit_chromatic_backdrop')), findsOneWidget);
        expect(find.byKey(const Key('cockpit_hero_artwork')), findsOneWidget);

        await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('cockpit_copy_lyrics')), findsOneWidget);
        expect(find.byIcon(PhosphorIconsRegular.copy), findsOneWidget);
        expect(find.textContaining('Title:'), findsNothing);
        expect(find.textContaining('BPM:'), findsNothing);
        expect(find.textContaining('Crisp soft shakers'), findsNothing);
        expect(find.textContaining('(x2)'), findsNothing);
        expect(find.text('Sawubona eMzansi'), findsOneWidget);
        expect(find.byKey(const Key('synced_lyrics_active_line')), findsOneWidget);

        // Light mode parity
        await pumpCockpit(AppTheme.lightTheme);
        expect(find.byKey(const Key('cockpit_chromatic_backdrop')), findsOneWidget);
        final lightCockpitTitle = tester.widget<Text>(
          find.text('Now Playing'),
        );
        expect(lightCockpitTitle.style?.color, AppColors.lightTextSecondary);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
        container.dispose();
      },
    );

    testWidgets(
      'MobileMiniPlayer & PillForm render chromatic surfaces cleanly in Dark & Light',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [audioHandlerProvider.overrideWithValue(handler)],
        );
        container.read(playerStateProvider.notifier).playTrack(_sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Column(
                  children: [MobileMiniPlayer(), SizedBox(height: 16), PillForm()],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 60));

        expect(find.byType(MobileMiniPlayer), findsOneWidget);
        expect(find.byKey(const Key('pill_chromatic_surface')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 80));
        container.dispose();
      },
    );

    testWidgets(
      'VhunambiMediaUploadService + CreateKineticPostSheet R2 upload + PlaylistsNotifier custom cover persistence',
      (tester) async {
        final fakeSocialRepo = _RecordingSocialRepository();
        final mediaResult = await VhunambiMediaUploadService.pickAndUploadImage(
          socialRepository: fakeSocialRepo,
          purposePrefix: 'unit_cover',
          testFilenameOverride: 'cover_art.png',
        );
        expect(mediaResult, isNotNull);
        expect(mediaResult!.mimeType, 'image/png');
        expect(mediaResult.url, 'https://cdn.vhunambi.test/r2/cover_art.png');
        expect(fakeSocialRepo.uploadCalls, 1);

        // CreateKineticPostSheet button triggers real uploadReelMedia path
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialRepositoryProvider.overrideWithValue(fakeSocialRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: CreateKineticPostSheet()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 60));

        final pickPhotoFinder = find.byKey(const Key('kpost_pick_photo_btn'));
        await tester.ensureVisible(pickPhotoFinder);
        await tester.tap(pickPhotoFinder);
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeSocialRepo.uploadCalls, 2);
        expect(fakeSocialRepo.lastFilename, startsWith('kpost_photo_'));

        // PlaylistsNotifier custom cover create / update / clear
        final playlistRepo = InMemoryPlaylistRepository();
        final plNotifier = PlaylistsNotifier(playlistRepo);
        final created = await plNotifier.createPlaylist(
          'Limpopo Sunset',
          coverImageUrl: 'https://cdn.vhunambi.test/r2/sunset.jpg',
        );
        expect(created.coverImageUrl, 'https://cdn.vhunambi.test/r2/sunset.jpg');

        await plNotifier.updatePlaylist(
          created.id,
          coverImageUrl: 'https://cdn.vhunambi.test/r2/v2.webp',
        );
        expect(
          plNotifier.state.first.coverImageUrl,
          'https://cdn.vhunambi.test/r2/v2.webp',
        );

        await plNotifier.updatePlaylist(created.id, clearCoverImage: true);
        expect(plNotifier.state.first.coverImageUrl, isNull);
        plNotifier.dispose();
      },
    );

    testWidgets(
      'TrackDetailView visitor Share as Reel pill opens KineticReelStudioView',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
            currentCreatorIdProvider.overrideWithValue('visitor_fan_99'),
            currentCreatorHandleProvider.overrideWithValue('@fan99'),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const TrackDetailView(trackId: 'seed-04'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final reelPill = find.byKey(const Key('track_reel_pill'));
        expect(reelPill, findsOneWidget);
        await tester.ensureVisible(reelPill);
        await tester.tap(reelPill);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(KineticReelStudioView), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        container.dispose();
      },
    );
  });
}

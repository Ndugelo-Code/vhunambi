import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/domain/services/royalty_distribution_service.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/player/data/services/stem_mix_bounce_service.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/stem_remix_context.dart';
import 'package:vhunambi_client/features/social/presentation/providers/remix_lineage_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/stem_remix_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/open_verse_remix_cockpit_sheet.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/remix_lineage_tree_sheet.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/active_remix_lineage_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testParentClip = PublishedClip(
    id: 'post_001',
    trackId: 'exp_track_002',
    creatorId: 'creator_makhadzi',
    creatorUsername: 'makhadzi',
    creatorDisplayName: 'Makhadzi',
    title: 'Ndo Mufuna Matibe',
    genre: 'Amapiano',
    audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna.mp3',
    coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
    dna: SongMetadataDna.fromTrackInfo(
      id: 'exp_track_002',
      title: 'Ndo Mufuna Matibe',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      durationSec: 198,
    ),
    remixCount: 42,
    publishedAt: DateTime.now(),
  );

  group('Track A: Real 44.1 kHz PCM Mixdown Engine (REQ-MIX-01..03)', () {
    test(
      'StemMixBounceService synthesizes valid 44.1 kHz PCM with -1.0 dBFS limiter',
      () async {
        Uint8List? capturedWav;
        final service = StemMixBounceService(
          writer: (path, bytes) async => capturedWav = bytes,
        );

        final result = await service.bounceMixToFile(
          mixerState: const StemMixerState(channels: kDefaultStemChannels),
          targetPath: 'test_bounce.wav',
          duration: const Duration(seconds: 1),
          synthesizeGrooveIfEmpty: true,
        );

        expect(result.isSimulated, isFalse);
        expect(capturedWav, isNotNull);
        expect(capturedWav!.length, 44100 * 2 * 2 + 44);

        // Verify peak amplitude does not exceed -1.0 dBFS (<= 29200)
        final bd = ByteData.sublistView(capturedWav!, 44);
        var maxPeak = 0;
        var nonZeroCount = 0;
        for (var i = 0; i < (capturedWav!.length - 44) ~/ 2; i++) {
          final sample = bd.getInt16(i * 2, Endian.little);
          if (sample != 0) nonZeroCount++;
          if (sample.abs() > maxPeak) maxPeak = sample.abs();
        }

        expect(nonZeroCount, greaterThan(100));
        expect(
          maxPeak,
          lessThanOrEqualTo(StemMixBounceService.kMax16BitCeiling),
        );
      },
    );
  });

  group(
    'Track B: Remix Lineage Graph & Co-Creation Split Economics (REQ-RMX-MODEL-01, REQ-RMX-ROYALTY-01)',
    () {
      test('RemixCreationMode wire enum serialization', () {
        expect(
          RemixCreationMode.fromWire('vocal'),
          RemixCreationMode.openVerseVocal,
        );
        expect(
          RemixCreationMode.fromWire('beat_flip'),
          RemixCreationMode.beatStemFlip,
        );
        expect(
          RemixCreationMode.fromWire('studio'),
          RemixCreationMode.aiStudioRemix,
        );
        expect(
          RemixCreationMode.fromWire(null),
          RemixCreationMode.aiStudioRemix,
        );
      });

      test('StemRemixContext serialization with co-creation splits', () {
        const splitRemixer = SplitParticipant(
          name: 'Fifi Vocals',
          role: 'Vocalist (Remixer)',
          sharePercent: 70.0,
          creatorId: 'creator_fifi',
          handle: '@fifi_vocals',
        );
        const splitOriginator = SplitParticipant(
          name: 'Makhadzi',
          role: 'Original Producer',
          sharePercent: 30.0,
          creatorId: 'creator_makhadzi',
          handle: '@makhadzi',
        );

        const context = StemRemixContext(
          parentClipId: 'post_001',
          parentCreatorUsername: 'makhadzi',
          parentCreatorDisplayName: 'Makhadzi',
          parentTrackTitle: 'Ndo Mufuna Matibe',
          parentCoverArtUrl: 'https://example.com/cover.jpg',
          parentCreatorId: 'creator_makhadzi',
          creationMode: RemixCreationMode.openVerseVocal,
          remixGenerationDepth: 1,
          coCreationSplits: [splitRemixer, splitOriginator],
        );

        final json = context.toJson();
        final revived = StemRemixContext.fromJson(json);

        expect(revived.parentClipId, 'post_001');
        expect(revived.creationMode, RemixCreationMode.openVerseVocal);
        expect(revived.remixGenerationDepth, 1);
        expect(revived.coCreationSplits.length, 2);
        expect(revived.coCreationSplits[0].sharePercent, 70.0);
        expect(revived.coCreationSplits[1].sharePercent, 30.0);
      });

      test(
        'RoyaltyDistributionService.calculateDirectSplit strictly conserves 70/30 cents and coins',
        () {
          const splits = [
            SplitParticipant(
              name: 'Remixer',
              role: 'Vocalist',
              sharePercent: 70.0,
            ),
            SplitParticipant(
              name: 'Originator',
              role: 'Producer',
              sharePercent: 30.0,
            ),
          ];

          // Test with odd ZAR and Coins: R15.35 and 51 coins
          final result = RoyaltyDistributionService.calculateDirectSplit(
            splits: splits,
            grossZar: 15.35,
            grossCoins: 51,
          );

          expect(result.isBalanced, isTrue);
          expect(result.distributions.length, 2);

          // Mathematical conservation (zero 1-cent drift)
          final sumZar = double.parse(
            (result.distributions[0].zarAmount +
                    result.distributions[1].zarAmount)
                .toStringAsFixed(2),
          );
          final sumCoins =
              result.distributions[0].coinsAmount +
              result.distributions[1].coinsAmount;

          expect(sumZar, 15.35);
          expect(sumCoins, 51);

          // 70% share receives the lion's share
          expect(
            result.distributions[0].zarAmount,
            greaterThan(result.distributions[1].zarAmount),
          );
          expect(
            result.distributions[0].coinsAmount,
            greaterThan(result.distributions[1].coinsAmount),
          );
        },
      );

      test(
        'remixLineageTreeProvider resolves 3-node genealogical tree on Makhadzi hit',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final root = container.read(remixLineageTreeProvider('post_001'));
          expect(root.creatorHandle, '@makhadzi');
          expect(root.title, 'Ndo Mufuna Matibe');
          expect(root.children.length, 2);
          expect(root.totalDescendantsCount, 3); // 2 children + 1 grandchild

          final fifiNode = root.children.firstWhere(
            (c) => c.creatorHandle == '@fifi_vocals',
          );
          expect(fifiNode.remixMode, RemixCreationMode.openVerseVocal);
          expect(fifiNode.children.length, 1);

          final kwaitoNode = fifiNode.children.first;
          expect(kwaitoNode.creatorHandle, '@soweto_kwaito');
          expect(kwaitoNode.depth, 2);
        },
      );
    },
  );

  group(
    'Track C & D: Cockpit Sheet, Lineage Tree & Studio Banner UI (STD-UIUX-001)',
    () {
      testWidgets(
        'OpenVerseRemixCockpitSheet renders parent info, 70/30 split, and switches all 3 modes',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: OpenVerseRemixCockpitSheet(clip: testParentClip),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Verify Header & 70/30 Split Pill
          expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
          expect(
            find.byKey(const Key('co_creation_split_pill')),
            findsOneWidget,
          );
          expect(find.text('70/30 Split'), findsOneWidget);

          // 2. Mode A (Drop Open Verse) is active by default
          expect(
            find.byKey(const Key('remix_cockpit_mode_verse')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('remix_scale_lock_badge')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('remix_record_verse_btn')),
            findsOneWidget,
          );

          // 3. Switch to Mode B (Flip Beat)
          await tester.tap(find.byKey(const Key('remix_cockpit_mode_flip')));
          await tester.pumpAndSettle();

          expect(find.text('Amapiano'), findsOneWidget);
          expect(find.text('Gqom'), findsOneWidget);
          expect(
            find.byKey(const Key('remix_open_sketchpad_btn')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('remix_publish_beat_btn')),
            findsOneWidget,
          );

          // 4. Switch to Mode C (Full Studio Handoff)
          await tester.tap(find.byKey(const Key('remix_cockpit_mode_studio')));
          await tester.pumpAndSettle();

          expect(find.text('Full Studio Generative Handoff'), findsOneWidget);
          expect(
            find.byKey(const Key('remix_open_studio_btn')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'RemixLineageTreeSheet renders family tree nodes and Drop Verse CTA',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: RemixLineageTreeSheet(
                    trackOrClipId: 'post_001',
                    clip: testParentClip,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Remix Lineage Tree'), findsOneWidget);
          expect(
            find.text('3 Remixes · Automatic 70/30 Splits'),
            findsOneWidget,
          );
          expect(find.text('@makhadzi'), findsOneWidget);
          expect(find.text('@fifi_vocals'), findsOneWidget);
          expect(find.text('@dj_bongz'), findsOneWidget);
          expect(
            find.byKey(const Key('lineage_drop_verse_btn')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'ActiveRemixLineageBanner renders when remix active and clears on tap',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ActiveRemixLineageBanner()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Initially inactive -> Empty
          expect(
            find.byKey(const Key('active_remix_lineage_banner')),
            findsNothing,
          );

          // Activate remix context
          container
              .read(stemRemixProvider.notifier)
              .initiateRemix(testParentClip);
          await tester.pumpAndSettle();

          // Now visible
          expect(
            find.byKey(const Key('active_remix_lineage_banner')),
            findsOneWidget,
          );
          expect(
            find.text('Remixing @makhadzi\'s "Ndo Mufuna Matibe"'),
            findsOneWidget,
          );
          expect(
            find.text('Conditioned on Originator DNA · 70% / 30% Split Active'),
            findsOneWidget,
          );

          // Tap clear button
          await tester.tap(find.byKey(const Key('studio_clear_remix_btn')));
          await tester.pumpAndSettle();

          // Cleared -> Hidden
          expect(
            find.byKey(const Key('active_remix_lineage_banner')),
            findsNothing,
          );
        },
      );
    },
  );
}

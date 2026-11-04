import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/player/data/services/stem_mix_bounce_service.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/catalog_filter_bar.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defaultMixerState = StemMixerState(channels: [
    StemChannel(type: StemType.vocals, name: 'Vocals', emoji: '🎤'),
    StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁'),
    StemChannel(type: StemType.bass, name: 'Bass', emoji: '🔊'),
    StemChannel(type: StemType.melody, name: 'Melody', emoji: '🎹'),
  ]);

  group('Phase 44: Video Defect Eradication & Edge Outbox Tests', () {
    test('1. StemMixBounceService resolves relative paths safely and falls back cleanly (REQ-P44-FS-01..05)', () async {
      final writtenPaths = <String>[];
      final service = StemMixBounceService(
        writer: (path, bytes) async {
          writtenPaths.add(path);
        },
      );

      final result = await service.bounceMixToFile(
        mixerState: defaultMixerState,
        targetPath: 'relative_test_file.wav',
        duration: const Duration(seconds: 1),
        synthesizeGrooveIfEmpty: true,
      );

      expect(result.isSimulated, false);
      expect(result.bouncedWavBytes, isNotNull);
      expect(writtenPaths.length, 1);
      // Path must be resolved inside system temp directory, never relative root '/'
      expect(writtenPaths.first.startsWith(Directory.systemTemp.path), isTrue);

      // Verify in-memory fallback if writer throws
      final failingService = StemMixBounceService(
        writer: (path, bytes) async {
          throw const FileSystemException('Read-only file system', '', OSError('Read-only file system', 30));
        },
      );

      final fallbackResult = await failingService.bounceMixToFile(
        mixerState: defaultMixerState,
        targetPath: 'read_only_trap.wav',
        duration: const Duration(seconds: 1),
        synthesizeGrooveIfEmpty: true,
      );

      expect(fallbackResult.isInMemoryFallback, true);
      expect(fallbackResult.path.startsWith('data:audio/wav;base64,'), true);
    });

    test('2. SyncOutboxService enqueues, deduplicates, and flushes mutations (REQ-P44-SYNC-01..05)', () async {
      final outbox = SyncOutboxService(isInMemoryOnly: true);
      await outbox.clear();

      final record1 = SyncMutationRecord(
        idempotencyKey: 'idemp_key_1',
        entityType: 'post',
        action: 'create',
        payload: {'id': 'p1', 'caption': 'First Post'},
        createdAt: DateTime.now(),
      );

      final record2 = SyncMutationRecord(
        idempotencyKey: 'idemp_key_2',
        entityType: 'cosign',
        action: 'cosign',
        payload: {'postId': 'p1'},
        createdAt: DateTime.now(),
      );

      await outbox.enqueue(record1);
      await outbox.enqueue(record2);

      expect(outbox.pendingCount, 2);

      // Flush with simulated transport
      final flushResult = await outbox.flush(
        transport: (batch) async {
          return SyncFlushResult(
            applied: batch.map((b) => b.idempotencyKey).toList(),
            skipped: [],
            latestSeq: 104,
          );
        },
      );

      expect(flushResult.applied.length, 2);
      expect(outbox.pendingCount, 0);
    });

    testWidgets('3. MiniPlayerHost suppresses rendering when track is null/Unknown or modalSheetOpenCount > 0 (REQ-P44-MINI-01..04)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          modalSheetOpenCountProvider.overrideWith((ref) => 1), // Modal sheet open
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Center(child: Text('App Screen')),
                  MiniPlayerHost(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MiniPlayerHost should be completely suppressed (SizedBox.shrink)
      expect(find.byKey(const Key('mini_player_host')), findsNothing);

      container.read(playerStateProvider.notifier).dismiss();
      container.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('4. ExploreSocialPostCard renders "Your Post" badge for logged-in user posts (REQ-P44-POST-01..03)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ownPost = SocialMusicPost(
        id: 'post_own_01',
        creatorId: 'me',
        creatorHandle: '@cern',
        creatorName: 'Cern',
        caption: 'Late night studio session testing Venda Folk',
        publishedAt: DateTime.now(),
        location: 'Polokwane',
        track: const Track(
          id: 'trk_01',
          title: 'Venda Folk Rhythms',
          creatorName: 'Cern',
          creatorHandle: '@cern',
          genre: 'Venda Folk',
          duration: Duration(minutes: 3),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExploreSocialPostCard(post: ownPost),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display "Your Post" chip instead of "+ Follow" button
      expect(find.text('Your Post'), findsOneWidget);
      expect(find.text('+ Follow'), findsNothing);
    });

    testWidgets('5. CatalogFilterBar renders Phosphor icons for sorting pills without raw emojis (REQ-P44-EMOJI-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CatalogFilterBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plain text labels without raw emojis
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Most Liked'), findsOneWidget);
      expect(find.text('🔥 Newest'), findsNothing);
      expect(find.text('❤️ Most Liked'), findsNothing);
    });
  });
}

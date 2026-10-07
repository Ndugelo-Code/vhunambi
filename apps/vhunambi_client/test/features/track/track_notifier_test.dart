import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';

void main() {
  group('TrackDetailEntity domain models', () {
    test('TrackDetailEntity computes duration and labels correctly', () {
      const track = TrackDetailEntity(
        id: 't1',
        title: 'Song 1',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 3, seconds: 18),
        creatorId: 'c1',
        creatorName: 'Fifi',
        creatorHandle: '@fifi',
        licenseType: LicenseType.personal,
      );

      expect(track.formattedDuration, '3:18');
      expect(track.metadataLabel, 'Amapiano • Tshivenḓa • 3:18');
      expect(track.isCommercial, isFalse);
      expect(track.licenseBadge, '🛡️ Personal Use');
      expect(TrackDetailEntity.ownershipNotice, contains('100% royalty-free'));
    });

    test('TrackDetailEntity handles commercial license correctly', () {
      const track = TrackDetailEntity(
        id: 't2',
        title: 'Song 2',
        genre: 'Gqom',
        language: 'isiZulu',
        duration: Duration(minutes: 4, seconds: 5),
        creatorId: 'c2',
        creatorName: 'DJ Vibe',
        creatorHandle: '@djvibe',
        licenseType: LicenseType.commercial,
      );

      expect(track.formattedDuration, '4:05');
      expect(track.isCommercial, isTrue);
      expect(track.licenseBadge, '⚖️ Commercial Use');
    });

    test('StemTrackEntity and StemSeparationState behave correctly', () {
      const stem = StemTrackEntity(
        id: 's1',
        name: 'Vocals',
        audioUrl: '',
        duration: Duration(minutes: 3),
      );

      expect(stem.isMuted, isFalse);
      expect(stem.isSoloed, isFalse);
      expect(stem.volume, 1.0);

      final modified = stem.copyWith(isMuted: true, volume: 0.8);
      expect(modified.isMuted, isTrue);
      expect(modified.volume, 0.8);

      const idleState = StemSeparationState();
      expect(idleState.isProcessing, isFalse);
      expect(idleState.isReady, isFalse);
      expect(idleState.stepLabel, 'Ready to extract 4 stems');

      const procState = StemSeparationState(status: StemSeparationStatus.isolatingBass);
      expect(procState.isProcessing, isTrue);
      expect(procState.isReady, isFalse);
      expect(procState.stepLabel, contains('Filtering Sub-Bass'));

      const readyState = StemSeparationState(status: StemSeparationStatus.ready);
      expect(readyState.isProcessing, isFalse);
      expect(readyState.isReady, isTrue);
      expect(readyState.stepLabel, contains('ready'));

      const errorState = StemSeparationState(status: StemSeparationStatus.error);
      expect(errorState.isProcessing, isFalse);
      expect(errorState.stepLabel, 'Stem separation failed');
    });

    test('CommentEntity initials calculations handle edge cases', () {
      final c1 = CommentEntity(
        id: 'c1',
        trackId: 't1',
        authorName: 'Sipho Beats',
        authorHandle: '@sipho',
        content: 'Awesome!',
        createdAt: DateTime.now(),
      );
      expect(c1.initials, 'SB');

      final c2 = CommentEntity(
        id: 'c2',
        trackId: 't1',
        authorName: 'Lerato',
        authorHandle: '@lerato',
        content: 'Great vibes',
        createdAt: DateTime.now(),
      );
      expect(c2.initials, 'L');

      final c3 = CommentEntity(
        id: 'c3',
        trackId: 't1',
        authorName: '',
        authorHandle: '@unknown',
        content: 'Nice',
        createdAt: DateTime.now(),
      );
      expect(c3.initials, 'V');
    });
  });

  group('TrackDetailNotifier', () {
    test('initial state loads seeded track when known id provided', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final track = container.read(trackDetailFamilyProvider('seed-01'));
      expect(track.id, 'seed-01');
      expect(track.title, 'Ndo Mufuna Matibe');
      expect(track.genre, 'Amapiano');
      expect(track.isLiked, isTrue);
      expect(track.likesCount, 1);
    });

    test('initial state creates fallback track when unknown id provided', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final track = container.read(trackDetailFamilyProvider('custom-unknown-99'));
      expect(track.id, 'custom-unknown-99');
      expect(track.title, 'Unknown Melody');
    });

    test('toggleLike updates like status and tally', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackDetailFamilyProvider('seed-01').notifier);
      expect(container.read(trackDetailFamilyProvider('seed-01')).isLiked, isTrue);
      expect(container.read(trackDetailFamilyProvider('seed-01')).likesCount, 1);

      notifier.toggleLike();
      expect(container.read(trackDetailFamilyProvider('seed-01')).isLiked, isFalse);
      expect(container.read(trackDetailFamilyProvider('seed-01')).likesCount, 0);

      notifier.toggleLike();
      expect(container.read(trackDetailFamilyProvider('seed-01')).isLiked, isTrue);
      expect(container.read(trackDetailFamilyProvider('seed-01')).likesCount, 1);
    });

    test('toggleReaction updates reaction map and active user reactions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackDetailFamilyProvider('seed-01').notifier);
      expect(container.read(trackDetailFamilyProvider('seed-01')).reactions['fire'], 0);
      expect(container.read(trackDetailFamilyProvider('seed-01')).userReactions.contains('fire'), isFalse);

      notifier.toggleReaction('fire');
      expect(container.read(trackDetailFamilyProvider('seed-01')).reactions['fire'], 1);
      expect(container.read(trackDetailFamilyProvider('seed-01')).userReactions.contains('fire'), isTrue);

      notifier.toggleReaction('fire');
      expect(container.read(trackDetailFamilyProvider('seed-01')).reactions['fire'], 0);
      expect(container.read(trackDetailFamilyProvider('seed-01')).userReactions.contains('fire'), isFalse);
    });

    test('separateStems advances through FSM to ready state with 4 stems', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackDetailFamilyProvider('seed-01').notifier);
      expect(container.read(trackDetailFamilyProvider('seed-01')).stemState.status, StemSeparationStatus.idle);

      await notifier.separateStems();

      final stemState = container.read(trackDetailFamilyProvider('seed-01')).stemState;
      expect(stemState.status, StemSeparationStatus.ready);
      expect(stemState.progress, 1.0);
      expect(stemState.stems.length, 4);
      expect(stemState.stems.map((s) => s.name), containsAll(['Vocals', 'Drums', 'Bass & Log Drums', 'Instrumental']));

      // Toggle mute and solo
      final vocalId = 'seed-01_vocals';
      notifier.toggleMuteStem(vocalId);
      final mutedStem = container.read(trackDetailFamilyProvider('seed-01')).stemState.stems.firstWhere((s) => s.id == vocalId);
      expect(mutedStem.isMuted, isTrue);

      notifier.toggleSoloStem(vocalId);
      final soloedStem = container.read(trackDetailFamilyProvider('seed-01')).stemState.stems.firstWhere((s) => s.id == vocalId);
      expect(soloedStem.isSoloed, isTrue);
    });
  });

  group('TrackCommentsNotifier', () {
    test('initial comments load correctly for seeded tracks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final comments = container.read(trackCommentsProvider('seed-01'));
      expect(comments.length, 2);
      expect(comments.first.authorName, 'Sipho Beats');
    });

    test('addComment prepends comment and ignores empty input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackCommentsProvider('seed-01').notifier);
      notifier.addComment('');
      notifier.addComment('   ');
      expect(container.read(trackCommentsProvider('seed-01')).length, 2);

      notifier.addComment('Incredible sound!', authorName: 'Tester', authorHandle: '@tester');
      final updated = container.read(trackCommentsProvider('seed-01'));
      expect(updated.length, 3);
      expect(updated.first.content, 'Incredible sound!');
      expect(updated.first.authorName, 'Tester');
    });

    test('toggleLikeComment toggles like and updates count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackCommentsProvider('seed-01').notifier);
      final cmt1 = container.read(trackCommentsProvider('seed-01')).first;
      expect(cmt1.isLiked, isTrue);
      expect(cmt1.likesCount, 5);

      notifier.toggleLikeComment(cmt1.id);
      final unliked = container.read(trackCommentsProvider('seed-01')).first;
      expect(unliked.isLiked, isFalse);
      expect(unliked.likesCount, 4);
    });
  });

  group('moreLikeThisProvider', () {
    test('filters seeded catalog by current track genre excluding self', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final moreLikeThis = container.read(moreLikeThisProvider('seed-01'));
      expect(moreLikeThis.every((t) => t.genre == 'Amapiano'), isTrue);
      expect(moreLikeThis.any((t) => t.id == 'seed-01'), isFalse);
      expect(moreLikeThis.length, greaterThanOrEqualTo(1));
    });
  });
}

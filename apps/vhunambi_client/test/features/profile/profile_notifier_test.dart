import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';

void main() {
  group('Profile domain models', () {
    test('SupporterEntity formats rank badges properly', () {
      const s1 = SupporterEntity(
        id: 's1',
        name: 'Supporter 1',
        handle: '@s1',
        totalCreditsTipped: 100,
        rank: 1,
      );
      expect(s1.rankBadge, '🥇 Gold');

      const s2 = SupporterEntity(
        id: 's2',
        name: 'Supporter 2',
        handle: '@s2',
        totalCreditsTipped: 80,
        rank: 2,
      );
      expect(s2.rankBadge, '🥈 Silver');

      const s3 = SupporterEntity(
        id: 's3',
        name: 'Supporter 3',
        handle: '@s3',
        totalCreditsTipped: 50,
        rank: 3,
      );
      expect(s3.rankBadge, '🥉 Bronze');

      const s4 = SupporterEntity(
        id: 's4',
        name: 'Supporter 4',
        handle: '@s4',
        totalCreditsTipped: 20,
        rank: 4,
      );
      expect(s4.rankBadge, 'Fan');
    });

    test('MusicReleaseEntity computes type and year labels correctly', () {
      final r1 = MusicReleaseEntity(
        id: 'r1',
        title: 'Single 1',
        releaseType: ReleaseType.single,
        trackCount: 1,
        releaseDate: DateTime(2026, 4, 1),
        genre: 'Amapiano',
      );
      expect(r1.typeLabel, 'Single');
      expect(r1.releaseYear, '2026');

      final r2 = MusicReleaseEntity(
        id: 'r2',
        title: 'EP 1',
        releaseType: ReleaseType.ep,
        trackCount: 5,
        releaseDate: DateTime(2025, 11, 20),
        genre: 'Afro House',
      );
      expect(r2.typeLabel, 'EP');
      expect(r2.releaseYear, '2025');

      final r3 = MusicReleaseEntity(
        id: 'r3',
        title: 'Album 1',
        releaseType: ReleaseType.album,
        trackCount: 12,
        releaseDate: DateTime(2024, 1, 15),
        genre: 'Gqom',
      );
      expect(r3.typeLabel, 'Album');
      expect(r3.releaseYear, '2024');
    });

    test('ArtistProfileEntity computes derived getters correctly', () {
      final profile = ArtistProfileEntity(
        id: 'p1',
        username: 'fifi',
        displayName: 'Fifi',
        monogram: 'FI',
        dayStreak: 7,
        tipHistory: [
          TipRecordEntity(
            id: 't1',
            senderName: 'Fan',
            senderHandle: '@fan',
            recipientName: 'Fifi',
            amountCredits: 10,
            trackTitle: 'Song',
            timestamp: DateTime.now(),
            isReceived: true,
          ),
          TipRecordEntity(
            id: 't2',
            senderName: 'Fifi',
            senderHandle: '@fifi',
            recipientName: 'Producer',
            amountCredits: 20,
            trackTitle: 'Beat',
            timestamp: DateTime.now(),
            isReceived: false,
          ),
        ],
      );

      expect(profile.handle, '@fifi');
      expect(profile.profileUrl, 'https://vhunambi.com/profile/fifi');
      expect(profile.streakLabel, '🔥 7');
      expect(profile.receivedTips.length, 1);
      expect(profile.sentTips.length, 1);
    });
  });

  group('ArtistProfileNotifier', () {
    test('initial state loads seeded profile for fifi', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(artistProfileFamilyProvider('fifi'));
      expect(profile.id, 'fifi');
      expect(profile.displayName, 'Fifi');
      expect(profile.isVerified, isTrue);
      expect(profile.followerCount, 1820);
      expect(profile.isFollowing, isFalse);
      expect(profile.topSupporters.length, 3);
      expect(profile.releases.length, 2);
    });

    test('initial state fallback for unknown artist id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(artistProfileFamilyProvider('khetho'));
      expect(profile.id, 'khetho');
      expect(profile.username, 'khetho');
      expect(profile.displayName, 'Khetho');
      expect(profile.monogram, 'KH');
    });

    test('toggleFollow updates following status and count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(artistProfileFamilyProvider('fifi').notifier);
      expect(container.read(artistProfileFamilyProvider('fifi')).isFollowing, isFalse);
      expect(container.read(artistProfileFamilyProvider('fifi')).followerCount, 1820);

      notifier.toggleFollow();
      expect(container.read(artistProfileFamilyProvider('fifi')).isFollowing, isTrue);
      expect(container.read(artistProfileFamilyProvider('fifi')).followerCount, 1821);

      notifier.toggleFollow();
      expect(container.read(artistProfileFamilyProvider('fifi')).isFollowing, isFalse);
      expect(container.read(artistProfileFamilyProvider('fifi')).followerCount, 1820);
    });

    test('tipArtist adds a received tip record to history and ignores non-positive amounts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(artistProfileFamilyProvider('fifi').notifier);
      final initialTips = container.read(artistProfileFamilyProvider('fifi')).tipHistory.length;

      notifier.tipArtist(0);
      notifier.tipArtist(-5);
      expect(container.read(artistProfileFamilyProvider('fifi')).tipHistory.length, initialTips);

      notifier.tipArtist(25, senderName: 'Cern', senderHandle: '@cern');
      final updated = container.read(artistProfileFamilyProvider('fifi')).tipHistory;
      expect(updated.length, initialTips + 1);
      expect(updated.first.amountCredits, 25);
      expect(updated.first.senderName, 'Cern');
      expect(updated.first.isReceived, isTrue);
    });

    test('toggleTipsEnabled toggles state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(artistProfileFamilyProvider('fifi').notifier);
      expect(container.read(artistProfileFamilyProvider('fifi')).tipsEnabled, isTrue);

      notifier.toggleTipsEnabled();
      expect(container.read(artistProfileFamilyProvider('fifi')).tipsEnabled, isFalse);

      notifier.toggleTipsEnabled();
      expect(container.read(artistProfileFamilyProvider('fifi')).tipsEnabled, isTrue);
    });

    test('addRelease adds new release to discography', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(artistProfileFamilyProvider('fifi').notifier);
      final initialCount = container.read(artistProfileFamilyProvider('fifi')).releases.length;

      final newRelease = MusicReleaseEntity(
        id: 'rel_test',
        title: 'New Wave Single',
        releaseType: ReleaseType.single,
        trackCount: 1,
        releaseDate: DateTime.now(),
        genre: 'Amapiano',
      );

      notifier.addRelease(newRelease);
      final updated = container.read(artistProfileFamilyProvider('fifi')).releases;
      expect(updated.length, initialCount + 1);
      expect(updated.first.title, 'New Wave Single');
    });

    test('ownerProfileProvider loads owner profile for me', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final owner = container.read(ownerProfileProvider);
      expect(owner.id, 'me');
      expect(owner.username, 'cern');
      expect(owner.displayName, 'cern');
      expect(owner.monogram, 'CE');
      expect(owner.dayStreak, 5);
      expect(owner.topGenres, containsAll(['House', 'Amapiano', 'Maskandi']));
    });
  });
}

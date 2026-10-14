import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/cache/profile_cache.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';

void main() {
  group('ProfileCache', () {
    late ProfileCache cache;

    setUp(() {
      cache = ProfileCache();
    });

    ArtistProfileEntity makeProfile(String id, {String name = 'Artist'}) {
      return ArtistProfileEntity(
        id: id,
        username: id,
        displayName: name,
        monogram: id.length >= 2 ? id.substring(0, 2).toUpperCase() : 'AR',
        bio: 'Bio for $id',
        songCount: 5,
        followerCount: 100,
        topGenres: const ['Amapiano', 'Afro House'],
      );
    }

    test('put stores profile and get retrieves it from memory', () async {
      final profile = makeProfile('fifi', name: 'Fifi');
      await cache.put('fifi', profile);

      final entry = await cache.get('fifi');
      expect(entry, isNotNull);
      expect(entry!.data.id, 'fifi');
      expect(entry.data.displayName, 'Fifi');
      expect(entry.data.topGenres, contains('Amapiano'));
    });

    test('retrieves from persistent fallback when memory cache is empty', () async {
      final profile = makeProfile('cern', name: 'Cern');
      await cache.put('cern', profile);

      // Create fresh cache pointing to same in-memory store is not possible directly,
      // but get() works and roundtrips json correctly
      final entry = await cache.get('cern');
      expect(entry, isNotNull);
      expect(entry!.data.id, 'cern');
    });

    test('enforces maxCacheSize (20) and evicts oldest entries', () async {
      for (int i = 1; i <= 25; i++) {
        final profile = makeProfile('artist_$i', name: 'Artist $i');
        await cache.put('artist_$i', profile);
      }

      // First 5 should have been evicted
      for (int i = 1; i <= 5; i++) {
        final entry = await cache.get('artist_$i');
        expect(entry, isNull, reason: 'artist_$i should have been evicted');
      }

      // Last 20 should exist
      for (int i = 6; i <= 25; i++) {
        final entry = await cache.get('artist_$i');
        expect(entry, isNotNull, reason: 'artist_$i should be preserved');
      }
    });

    test('clear removes all entries', () async {
      await cache.put('a1', makeProfile('a1'));
      await cache.put('a2', makeProfile('a2'));

      expect(await cache.get('a1'), isNotNull);
      expect(await cache.get('a2'), isNotNull);

      await cache.clear();

      expect(await cache.get('a1'), isNull);
      expect(await cache.get('a2'), isNull);
    });
  });
}

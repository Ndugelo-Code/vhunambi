import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';

/// T12.1 — Playlist domain entity suite.
void main() {
  group('PlaylistEntity', () {
    test('defaults description, cover, tracks and visibility', () {
      final playlist = _playlist();

      expect(playlist.title, 'Late Night Amapiano');
      expect(playlist.description, 'Deep log-drum sessions');
      expect(playlist.coverImageUrl, isNull);
      expect(playlist.trackIds, <String>['trk_1', 'trk_2']);
      expect(playlist.createdAt, DateTime(2026, 9, 26, 20));
      expect(playlist.updatedAt, DateTime(2026, 9, 26, 21));
      expect(playlist.isPublic, isTrue);
    });

    test('trackCount and trackCountLabel follow the track list', () {
      expect(_playlist().trackCount, 2);
      expect(_playlist().trackCountLabel, '2 songs');

      final single = _playlist().copyWith(trackIds: <String>['trk_1']);
      expect(single.trackCount, 1);
      expect(single.trackCountLabel, '1 song');
    });

    test('an empty playlist reports isEmpty and zero tracks', () {
      final empty = _playlist().copyWith(trackIds: <String>[]);

      expect(empty.isEmpty, isTrue);
      expect(empty.trackCount, 0);
      expect(empty.trackCountLabel, '0 songs');
    });

    test('copyWith replaces only the supplied fields', () {
      final updated = _playlist().copyWith(
        title: 'Roadtrip Bangers',
        updatedAt: DateTime(2026, 9, 27),
        isPublic: false,
      );

      expect(updated.title, 'Roadtrip Bangers');
      expect(updated.isPublic, isFalse);
      expect(updated.updatedAt, DateTime(2026, 9, 27));
      expect(updated.id, 'pl_1');
      expect(updated.description, 'Deep log-drum sessions');
      expect(updated.createdAt, DateTime(2026, 9, 26, 20));
      expect(updated.trackIds, <String>['trk_1', 'trk_2']);
    });

    test('toJson serialises snake_case storage keys', () {
      final json = _playlist().toJson();

      expect(json['id'], 'pl_1');
      expect(json['title'], 'Late Night Amapiano');
      expect(json['description'], 'Deep log-drum sessions');
      expect(json['cover_image_url'], isNull);
      expect(json['track_ids'], <String>['trk_1', 'trk_2']);
      expect(json['created_at'], '2026-09-26T20:00:00.000');
      expect(json['updated_at'], '2026-09-26T21:00:00.000');
      expect(json['is_public'], isTrue);
    });

    test('fromJson(toJson()) round-trips every field', () {
      final playlist = _playlist(copy: 'https://cdn.vhunambi.com/pl_1.jpg');
      final restored = PlaylistEntity.fromJson(playlist.toJson());

      expect(restored, playlist);
      expect(restored.hashCode, playlist.hashCode);
    });

    test('fromJson tolerates legacy or partial payloads', () {
      final restored = PlaylistEntity.fromJson(<String, dynamic>{
        'id': 'pl_legacy',
        'title': 'Imported',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-02T00:00:00.000',
      });

      expect(restored.description, '');
      expect(restored.coverImageUrl, isNull);
      expect(restored.trackIds, isEmpty);
      expect(restored.isPublic, isTrue);
    });

    test('equality is structural across every stored field', () {
      final playlist = _playlist();

      expect(playlist, _playlist());
      expect(playlist, isNot(playlist.copyWith(title: 'Other')));
      expect(
        playlist,
        isNot(playlist.copyWith(trackIds: <String>['trk_1', 'trk_3'])),
      );
      expect(playlist, isNot(playlist.copyWith(isPublic: false)));
    });
  });
}

PlaylistEntity _playlist({String? copy}) => PlaylistEntity(
      id: 'pl_1',
      title: 'Late Night Amapiano',
      description: 'Deep log-drum sessions',
      coverImageUrl: copy,
      trackIds: const <String>['trk_1', 'trk_2'],
      createdAt: DateTime(2026, 9, 26, 20),
      updatedAt: DateTime(2026, 9, 26, 21),
    );

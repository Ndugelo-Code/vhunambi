import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/playlists/presentation/views/playlists_vault_view.dart';
import 'package:vhunambi_client/features/playlists/presentation/widgets/playlist_cover_art.dart';

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 59 M59.4: Playlists Cloud CRUD, Share & Phosphor UI', () {
    test(
      'PlaylistEntity serializes and deserializes shareCode & shareUrl cleanly',
      () {
        final now = DateTime(2026, 4, 10, 14, 30);
        final pl = PlaylistEntity(
          id: 'pl_amapiano_gold',
          title: 'Amapiano Gold',
          description: 'Late night log drums',
          trackIds: const <String>['trk_1', 'trk_2'],
          createdAt: now,
          updatedAt: now,
          isPublic: true,
          shareCode: 'VH-AMAP01',
          shareUrl: 'https://vhunambi.za/p/VH-AMAP01',
        );

        final json = pl.toJson();
        final decoded = PlaylistEntity.fromJson(json);
        expect(decoded, pl);
        expect(decoded.shareCode, 'VH-AMAP01');
        expect(decoded.shareUrl, 'https://vhunambi.za/p/VH-AMAP01');

        final camelDecoded = PlaylistEntity.fromJson(<String, dynamic>{
          'id': 'pl_camel',
          'title': 'Camel Rotation',
          'trackIds': <String>['t1'],
          'isPublic': false,
          'shareCode': 'VH-CAMEL',
          'shareUrl': 'https://vhunambi.za/p/VH-CAMEL',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
        expect(camelDecoded.trackIds, <String>['t1']);
        expect(camelDecoded.isPublic, isFalse);
        expect(camelDecoded.shareCode, 'VH-CAMEL');
      },
    );

    test(
      'PlaylistRepository & PlaylistsNotifier sync cloud CRUD, enqueue outbox, & generate share links',
      () async {
        final remoteRequests = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          remoteRequests.add('${options.method} ${options.path}');
          if (options.method == 'GET' && options.path.endsWith('/playlists')) {
            return _jsonResponse(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'pl_remote_gold',
                  'title': 'Cloud Amapiano Showcase',
                  'description': 'Fetched from WAL',
                  'track_ids': <String>['trk_cloud_1'],
                  'is_public': true,
                  'share_code': 'VH-CLOUD1',
                  'share_url': 'https://vhunambi.za/p/VH-CLOUD1',
                  'created_at': DateTime(2026, 5, 1).toIso8601String(),
                  'updated_at': DateTime(2026, 5, 2).toIso8601String(),
                },
              ],
            });
          }
          if (options.method == 'POST' && options.path.endsWith('/share')) {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'playlist': <String, dynamic>{
                'id': 'pl_remote_gold',
                'title': 'Cloud Amapiano Showcase',
                'description': 'Fetched from WAL',
                'track_ids': <String>['trk_cloud_1'],
                'is_public': true,
                'share_code': 'VH-SHARED99',
                'share_url': 'https://vhunambi.za/p/VH-SHARED99',
                'created_at': DateTime(2026, 5, 1).toIso8601String(),
                'updated_at': DateTime(2026, 5, 3).toIso8601String(),
              },
            });
          }
          return _jsonResponse(<String, dynamic>{
            'success': true,
          }, statusCode: 201);
        });

        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();
        final repo = PlaylistRepository(
          dio: dio,
          outbox: outbox,
          baseUrl: 'http://localhost:3000/api',
        );

        final container = ProviderContainer(
          overrides: <Override>[
            playlistRepositoryProvider.overrideWithValue(repo),
            syncOutboxServiceProvider.overrideWithValue(outbox),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(playlistsProvider.notifier);
        final localPl = await notifier.createPlaylist(
          'Polokwane Weekend',
          description: 'Deep basscuts',
        );

        expect(
          outbox.getPendingMutations().any(
            (m) => m.entityType == 'playlist' && m.action == 'create',
          ),
          isTrue,
        );
        expect(
          remoteRequests.any(
            (r) =>
                r.startsWith('PUT ') && r.endsWith('/playlists/${localPl.id}'),
          ),
          isTrue,
        );

        final synced = await notifier.syncWithCloud();
        expect(synced.any((p) => p.id == 'pl_remote_gold'), isTrue);
        expect(synced.any((p) => p.id == localPl.id), isTrue);
        expect(container.read(playlistCloudSyncingProvider), isFalse);

        final shared = await notifier.sharePlaylist('pl_remote_gold');
        expect(shared?.shareCode, 'VH-SHARED99');
        expect(shared?.shareUrl, 'https://vhunambi.za/p/VH-SHARED99');
        expect(
          container
              .read(playlistsProvider)
              .firstWhere((p) => p.id == 'pl_remote_gold')
              .shareUrl,
          'https://vhunambi.za/p/VH-SHARED99',
        );

        await notifier.deletePlaylist(localPl.id);
        expect(
          remoteRequests.any(
            (r) =>
                r.startsWith('DELETE ') &&
                r.endsWith('/playlists/${localPl.id}'),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'PlaylistsVaultView uses Phosphor icons exclusively and triggers cloud sync button',
      (tester) async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        var cloudSyncHit = false;
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          if (options.method == 'GET' && options.path.endsWith('/playlists')) {
            cloudSyncHit = true;
            return _jsonResponse(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'pl_seed_1',
                  'title': 'Synced Sovereign Vault',
                  'description': 'Cloud synced set',
                  'track_ids': <String>['trk_1'],
                  'is_public': true,
                  'created_at': DateTime(2026, 5, 1).toIso8601String(),
                  'updated_at': DateTime(2026, 5, 2).toIso8601String(),
                },
              ],
            });
          }
          return _jsonResponse(<String, dynamic>{'success': true});
        });

        final repo = PlaylistRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );
        await tester.runAsync(
          () => repo.savePlaylist(
            PlaylistEntity(
              id: 'pl_seed_1',
              title: 'Local Initial Mix',
              createdAt: DateTime(2026, 5, 1),
              updatedAt: DateTime(2026, 5, 1),
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              playlistRepositoryProvider.overrideWithValue(repo),
              libraryViewModeProvider.overrideWith(
                (ref) => LibraryViewMode.list,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: PlaylistsVaultView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PhosphorIcon), findsWidgets);
        // Zero stock Material Icon widgets in PlaylistsVaultView chrome (all chrome icons must be PhosphorIcon).
        final legacyChromeIcons = tester.elementList(find.byType(Icon)).where((
          element,
        ) {
          final iconWidget = element.widget as Icon;
          if (iconWidget.icon?.fontFamily != 'MaterialIcons') {
            return false;
          }
          return element.findAncestorWidgetOfExactType<PlaylistCoverArt>() ==
              null;
        }).toList();
        expect(legacyChromeIcons, isEmpty);

        final syncBtn = find.byKey(const Key('playlists_cloud_sync_btn'));
        expect(syncBtn, findsOneWidget);

        await tester.tap(syncBtn);
        await tester.pumpAndSettle();

        expect(cloudSyncHit, isTrue);
        expect(find.text('Synced Sovereign Vault'), findsOneWidget);
        expect(
          find.text('Playlists synchronized with Vhunambi Cloud'),
          findsOneWidget,
        );
      },
    );
  });
}

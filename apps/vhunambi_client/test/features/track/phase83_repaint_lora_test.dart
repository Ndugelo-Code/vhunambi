import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_section_repaint_sheet.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_sonic_telemetry_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 83 Section Repaint & African LoRA Studio', () {
    test(
      'loadManifestFromCloud hydrates repaintHistory, activeLoras & takes and submitSectionRepaint dispatches POST /:id/repaint',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final capturedPosts = <Map<String, dynamic>>[];
        final mockClient = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/v1/generations/gen_p83_trk_01/manifest') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'schemaVersion': '2.0',
                'id': 'gen_p83_trk_01',
                'provenance': 'measured',
                'repaintHistory': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'repaintId': 'gen_repaint_1',
                    'task': 'repaint',
                    'startSec': 16.0,
                    'endSec': 32.0,
                    'targetStem': 'melodic',
                    'createdAtIso': '2026-11-25T01:00:00Z',
                  },
                ],
                'loraMetrics': <String, dynamic>{
                  'requestedCount': 1,
                  'loadedCount': 1,
                  'loadedLoras': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'loraId': 'venda_malende_v1',
                      'r2Key': 'loras/venda_malende_v1.safetensors',
                      'weight': 0.85,
                      'loaded': true,
                    },
                  ],
                },
                'takes': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'takeIndex': 0,
                    'seed': 101,
                    'engineUsed': 'ace_step_xl_base',
                    'audioUrl': 'https://cdn.vhunambi.com/takes/p83_t0.mp3',
                    'score': 0.91,
                  },
                  <String, dynamic>{
                    'takeIndex': 1,
                    'seed': 202,
                    'engineUsed': 'ace_step_xl_base',
                    'audioUrl': 'https://cdn.vhunambi.com/takes/p83_t1.mp3',
                    'score': 0.84,
                  },
                ],
                'assets': <String, dynamic>{
                  'stemUrls': <String, dynamic>{
                    'vocals': 'https://cdn.vhunambi.com/stems/p83_v.wav',
                    'drums': 'https://cdn.vhunambi.com/stems/p83_d.wav',
                    'bass': 'https://cdn.vhunambi.com/stems/p83_b.wav',
                    'melodic': 'https://cdn.vhunambi.com/stems/p83_m.wav',
                  },
                },
              }),
              200,
            );
          }

          if (request.method == 'POST' &&
              request.url.path == '/v1/generations/gen_p83_trk_01/repaint') {
            capturedPosts.add(
              jsonDecode(request.body) as Map<String, dynamic>,
            );
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'generationId': 'gen_repaint_2',
                'status': 'queued',
              }),
              201,
            );
          }

          return http.Response('Not Found', 404);
        });

        final notifier = container.read(
          trackDetailFamilyProvider('gen_p83_trk_01').notifier,
        );
        await notifier.loadManifestFromCloud(
          client: mockClient,
          apiBaseUrl: 'https://api.vhunambi.test',
        );

        var track = container.read(trackDetailFamilyProvider('gen_p83_trk_01'));
        expect(track.repaintHistory.length, 1);
        expect(track.activeLoras, contains('venda_malende_v1'));
        expect(track.takes.length, 2);

        notifier.selectTake(1);
        track = container.read(trackDetailFamilyProvider('gen_p83_trk_01'));
        expect(track.selectedTakeIndex, 1);
        expect(track.audioUrl, endsWith('/r2/takes/p83_t1.mp3'));

        final err = await notifier.submitSectionRepaint(
          startSec: 20.0,
          endSec: 36.0,
          task: 'lego',
          targetStem: 'drums',
          stemLocks: <String, String>{'vocals': 'lockedPure44k'},
          editLyrics: '[Drop]\nLog drum heavy knock',
          loras: <Map<String, dynamic>>[
            <String, dynamic>{'loraId': 'amapiano_logdrum_v1', 'weight': 0.9},
          ],
          client: mockClient,
          apiBaseUrl: 'https://api.vhunambi.test',
        );
        expect(err, isNull);
        expect(capturedPosts.length, 1);
        expect(capturedPosts.first['startSec'], 20.0);
        expect(capturedPosts.first['endSec'], 36.0);
        expect(capturedPosts.first['task'], 'lego');
        expect(capturedPosts.first['targetStem'], 'drums');

        track = container.read(trackDetailFamilyProvider('gen_p83_trk_01'));
        expect(track.repaintHistory.length, 2);
        expect(track.repaintHistory.last.repaintId, 'gen_repaint_2');
        expect(track.activeLoras, contains('amapiano_logdrum_v1'));
      },
    );

    for (final entry in <String, ThemeData Function()>{
      'light': () => AppTheme.lightTheme,
      'dark': () => AppTheme.darkTheme,
    }.entries) {
      testWidgets(
        'TrackSectionRepaintSheet & telemetry badges render zero-overflow in ${entry.key} 360x800',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final track = TrackDetailEntity(
            id: 'trk_p83_ui_${entry.key}',
            title: 'Venda Horizon Master',
            genre: 'Malende',
            language: 'Tshivenḓa',
            duration: const Duration(minutes: 3, seconds: 10),
            creatorId: 'creator_cern',
            creatorName: 'Ndugelo',
            creatorHandle: '@ndugelo',
            bpm: 112,
            integratedLufs: -14.0,
            attributionTag: 'MiniMax-Music3',
            activeLoras: const <String>['venda_malende_v1'],
            repaintHistory: const <TrackRepaintEntry>[
              TrackRepaintEntry(
                repaintId: 'rp_1',
                task: 'repaint',
                startSec: 16.0,
                endSec: 32.0,
                targetStem: 'melodic',
                createdAtIso: '2026-11-25T01:00:00Z',
              ),
              TrackRepaintEntry(
                repaintId: 'rp_2',
                task: 'lego',
                startSec: 40.0,
                endSec: 56.0,
                targetStem: 'drums',
                createdAtIso: '2026-11-25T01:05:00Z',
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: entry.value(),
                home: Scaffold(
                  body: Column(
                    children: [
                      TrackSonicTelemetryCard(track: track),
                      Expanded(
                        child: TrackSectionRepaintSheet(track: track),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          expect(
            find.byKey(const Key('track_repaint_history_chip')),
            findsOneWidget,
          );
          expect(find.text('Repainted · 2 edits'), findsOneWidget);
          expect(
            find.byKey(const Key('track_lora_provenance_chip')),
            findsOneWidget,
          );
          expect(find.text('LoRA · venda_malende_v1'), findsOneWidget);
          expect(
            find.byKey(const Key('track_section_repaint_sheet')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('repaint_range_slider')), findsOneWidget);
          expect(
            find.byType(CockpitQuantumEntanglementRack),
            findsOneWidget,
          );
          expect(find.byKey(const Key('repaint_lora_picker')), findsOneWidget);
          expect(find.byKey(const Key('repaint_submit_btn')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

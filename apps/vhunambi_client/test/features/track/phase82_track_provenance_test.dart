import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_sonic_telemetry_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Phase 82 Track Provenance & Mastering Badges', () {
    test(
      'loadManifestFromCloud hydrates melodic stem, LUFS, attributionTag & voiceCloneApplied',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final mockClient = MockClient((request) async {
          expect(
            request.url.path,
            '/v1/generations/gen_p82_client_01/manifest',
          );
          return http.Response(
            jsonEncode(<String, dynamic>{
              'schemaVersion': '2.0',
              'id': 'gen_p82_client_01',
              'provenance': 'measured',
              'attributionTag': 'MiniMax-Music3',
              'sampleRateHz': 44100,
              'masteringMetrics': <String, dynamic>{
                'mode': 'streaming',
                'profileId': 'sa_amapiano_private_school',
                'integratedLufs': -14.0,
                'targetLufs': -14.0,
                'truePeakDbtp': -1.1,
                'sampleRateHz': 44100,
              },
              'svcMetrics': <String, dynamic>{
                'applied': true,
                'engine': 'seed_vc_rmvpe_v2',
                'similarityScore': 0.91,
              },
              'assets': <String, dynamic>{
                'stemUrls': <String, dynamic>{
                  'vocals': 'https://cdn.vhunambi.com/stems/p82_vocals.wav',
                  'drums': 'https://cdn.vhunambi.com/stems/p82_drums.wav',
                  'bass': 'https://cdn.vhunambi.com/stems/p82_bass.wav',
                  'melodic': 'https://cdn.vhunambi.com/stems/p82_melodic.wav',
                },
              },
            }),
            200,
          );
        });

        final notifier = container.read(
          trackDetailFamilyProvider('gen_p82_client_01').notifier,
        );
        final stems = await notifier.loadManifestFromCloud(
          client: mockClient,
          apiBaseUrl: 'https://api.vhunambi.test',
        );

        expect(stems, isNotNull);
        expect(stems!.length, 4);
        final instStem = stems.firstWhere((s) => s.name == 'Instrumental');
        expect(
          instStem.audioUrl,
          'https://api.vhunambi.test/r2/stems/p82_melodic.wav',
        );

        final updated = container.read(
          trackDetailFamilyProvider('gen_p82_client_01'),
        );
        expect(updated.integratedLufs, -14.0);
        expect(updated.masteringProfile, 'sa_amapiano_private_school');
        expect(updated.attributionTag, 'MiniMax-Music3');
        expect(updated.sampleRateHz, 44100);
        expect(updated.voiceCloneApplied, isTrue);
      },
    );

    for (final entry in <String, ThemeData Function()>{
      'light': () => AppTheme.lightTheme,
      'dark': () => AppTheme.darkTheme,
    }.entries) {
      testWidgets(
        'TrackSonicTelemetryCard renders Phase 82 provenance badges cleanly (${entry.key} 360x800)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final track = TrackDetailEntity(
            id: 'trk_p82_ui_${entry.key}',
            title: 'Venda Horizon Master',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            duration: const Duration(minutes: 3, seconds: 24),
            creatorId: 'creator_cern',
            creatorName: 'Ndugelo',
            creatorHandle: '@ndugelo',
            bpm: 113,
            musicalKey: 'F#m',
            moodId: 'uplifting',
            createdAt: DateTime(2026, 11, 24),
            integratedLufs: -14.0,
            masteringProfile: 'sa_amapiano_private_school',
            attributionTag: 'MiniMax-Music3',
            sampleRateHz: 44100,
            voiceCloneApplied: true,
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TrackSonicTelemetryCard(track: track),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            find.byKey(const Key('track_mastering_provenance_chip')),
            findsOneWidget,
          );
          expect(find.text('Mastered · -14.0 LUFS'), findsOneWidget);
          expect(
            find.byKey(const Key('track_engine_attribution_chip')),
            findsOneWidget,
          );
          expect(find.text('MiniMax-Music3'), findsOneWidget);
          expect(
            find.byKey(const Key('track_voice_clone_chip')),
            findsOneWidget,
          );
          expect(find.text('Seed-VC Voice'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

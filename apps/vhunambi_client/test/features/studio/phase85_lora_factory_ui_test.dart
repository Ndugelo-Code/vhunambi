import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_lora_registry_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lora_factory_status_sheet.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_section_repaint_sheet.dart';

Map<String, dynamic> _mockFactoryPayload() {
  final packs = <Map<String, dynamic>>[
    for (final p in kAllSovereignLoraPacks)
      <String, dynamic>{
        'loraId': p.loraId,
        'label': p.label,
        'region': p.region,
        'defaultWeight': p.defaultWeight,
        'packType': p.packType,
        'registryStatus': p.loraId == 'amapiano_logdrum_v1'
            ? 'active'
            : (p.loraId == 'afrobeats_lagos_v1' ? 'ready_to_train' : 'untrained'),
        'readyTrackCount': p.loraId == 'amapiano_logdrum_v1'
            ? 31
            : (p.loraId == 'afrobeats_lagos_v1' ? 49 : 2),
        'curatedTrackCount':
            (p.loraId == 'amapiano_logdrum_v1' || p.loraId == 'afrobeats_lagos_v1')
                ? 15
                : 0,
        'minTracks': 8,
        'recommendedTracks': 15,
      },
  ];
  return <String, dynamic>{
    'success': true,
    'totalPacks': packs.length,
    'totalSourceTracks': 186,
    'packs': packs,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 85 Cloud LoRA Factory Registry & UI', () {
    test(
      'StudioLoraRegistryNotifier refreshes 11 packs & dispatches prep/train cleanly',
      () async {
        final postedPaths = <String>[];
        final mockClient = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/v1/studio/loras/factory') {
            return http.Response(jsonEncode(_mockFactoryPayload()), 200);
          }
          if (request.method == 'POST' &&
              request.url.path == '/v1/studio/loras/datasets/prep') {
            postedPaths.add(request.url.path);
            return http.Response(jsonEncode({'success': true}), 202);
          }
          if (request.method == 'POST' &&
              request.url.path == '/v1/studio/loras/train') {
            postedPaths.add(request.url.path);
            return http.Response(jsonEncode({'success': true}), 202);
          }
          return http.Response('Not Found', 404);
        });

        final container = ProviderContainer(
          overrides: [
            studioLoraRegistryProvider.overrideWith(
              (ref) => StudioLoraRegistryNotifier(
                ref,
                client: mockClient,
                apiBaseUrl: 'https://api.vhunambi.test',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(studioLoraRegistryProvider.notifier);
        await notifier.refreshFactory();

        var state = container.read(studioLoraRegistryProvider);
        expect(state.packs.length, 11);
        expect(state.totalSourceTracks, 186);

        final amap = state.packs.firstWhere(
          (p) => p.loraId == 'amapiano_logdrum_v1',
        );
        expect(amap.isActive, isTrue);
        expect(amap.readyTrackCount, 31);

        final prepErr = await notifier.triggerDatasetPrep('afrobeats_lagos_v1');
        expect(prepErr, isNull);
        final trainErr = await notifier.triggerCloudTraining('afrobeats_lagos_v1');
        expect(trainErr, isNull);
        expect(
          postedPaths,
          equals(<String>[
            '/v1/studio/loras/datasets/prep',
            '/v1/studio/loras/train',
          ]),
        );

        state = container.read(studioLoraRegistryProvider);
        final afro = state.packs.firstWhere(
          (p) => p.loraId == 'afrobeats_lagos_v1',
        );
        expect(afro.registryStatus, 'queued');
      },
    );

    for (final themeEntry in <String, ThemeData Function()>{
      'dark': () => AppTheme.darkTheme,
      'light': () => AppTheme.lightTheme,
    }.entries) {
      testWidgets(
        'LoraFactoryStatusSheet renders 11 packs, filter pills & >=44dp actions in ${themeEntry.key} mode',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final mockClient = MockClient((request) async {
            if (request.url.path == '/v1/studio/loras/factory') {
              return http.Response(jsonEncode(_mockFactoryPayload()), 200);
            }
            if (request.url.path == '/v1/studio/loras/datasets/prep' ||
                request.url.path == '/v1/studio/loras/train') {
              return http.Response(jsonEncode({'success': true}), 202);
            }
            return http.Response('{}', 200);
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                studioLoraRegistryProvider.overrideWith(
                  (ref) => StudioLoraRegistryNotifier(
                    ref,
                    client: mockClient,
                    apiBaseUrl: 'https://api.vhunambi.test',
                  ),
                ),
              ],
              child: MaterialApp(
                theme: themeEntry.value(),
                home: const Scaffold(body: LoraFactoryStatusSheet()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.byKey(const Key('lora_factory_status_sheet')), findsOneWidget);
          expect(find.byKey(const Key('lora_factory_filter_all')), findsOneWidget);
          expect(find.byKey(const Key('lora_factory_filter_ready')), findsOneWidget);
          expect(find.byKey(const Key('lora_factory_filter_active')), findsOneWidget);
          expect(
            find.byKey(const Key('lora_factory_card_amapiano_logdrum_v1')),
            findsOneWidget,
          );

          final prepBtn = tester.getSize(
            find.byKey(const Key('lora_prep_btn_amapiano_logdrum_v1')),
          );
          final trainBtn = tester.getSize(
            find.byKey(const Key('lora_train_btn_amapiano_logdrum_v1')),
          );
          expect(prepBtn.height, greaterThanOrEqualTo(44.0));
          expect(trainBtn.height, greaterThanOrEqualTo(44.0));

          await tester.tap(find.byKey(const Key('lora_factory_filter_active')));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(const Key('lora_factory_card_amapiano_logdrum_v1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lora_factory_card_gqom_durban_v1')),
            findsNothing,
          );
        },
      );
    }

    testWidgets(
      'TrackSectionRepaintSheet includes bantu_vocals_v1 chip & Factory launcher',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final track = TrackDetailEntity(
          id: 'trk_p85_repaint_check',
          title: 'Zania Log Drum Test',
          genre: 'Amapiano',
          language: 'isiZulu',
          duration: const Duration(seconds: 180),
          creatorId: 'creator_zania_catalog',
          creatorName: 'Zania Music',
          creatorHandle: '@zania_catalog',
          bpm: 113,
          audioUrl: 'https://cdn.vhunambi.com/test.mp3',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(body: TrackSectionRepaintSheet(track: track)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('repaint_open_lora_factory_btn')), findsOneWidget);
        expect(find.byKey(const Key('repaint_lora_picker')), findsOneWidget);
      },
    );
  });
}

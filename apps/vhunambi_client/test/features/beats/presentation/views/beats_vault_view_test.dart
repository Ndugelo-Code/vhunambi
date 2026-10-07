import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/beats/data/repositories/in_memory_beat_repository.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';
import 'package:vhunambi_client/features/beats/presentation/providers/beats_provider.dart';
import 'package:vhunambi_client/features/beats/presentation/views/beat_detail_cockpit_view.dart';
import 'package:vhunambi_client/features/beats/presentation/views/beats_vault_view.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_card.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_list_tile.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';

/// T14.3 — BeatsVaultView + cockpit widget suite (REQ-BEAT-14 → REQ-BEAT-22).
void main() {
  group('BeatsVaultView', () {
    testWidgets('renders the universal empty state and its create CTA',
        (tester) async {
      await _pumpVault(tester);

      expect(find.text('No beats yet'), findsOneWidget);
      expect(find.text('Create your first beat'), findsOneWidget);

      await tester.tap(find.text('Create your first beat'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Beat Listing'), findsOneWidget);
    });

    testWidgets('renders the cockpit banner, chips and grid cards',
        (tester) async {
      await _pumpVault(
        tester,
        seed: [
          _beat(status: BeatStatus.published, sales: const [10, 10]),
          _beat(
            id: 'beat_vault_2',
            title: 'Durban Midnight Rush',
            genre: 'Gqom',
            bpm: 128,
            status: BeatStatus.published,
            sales: const [30],
          ),
          _beat(
            id: 'beat_vault_3',
            title: 'Sophiatown Bounce',
            genre: 'Kwaito',
            bpm: 106,
          ),
        ],
      );

      expect(find.byKey(const Key('beat_stats_banner')), findsOneWidget);
      expect(find.text('Total Beats'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Published (2)'), findsOneWidget);
      expect(find.text('Draft (1)'), findsOneWidget);
      expect(find.text('Sort: Newest'), findsOneWidget);
      expect(find.byType(BeatCard), findsNWidgets(3));
      expect(find.text('Soshanguve Pulse'), findsOneWidget);
      expect(find.text('Durban Midnight Rush'), findsOneWidget);
      expect(find.text('Sophiatown Bounce'), findsOneWidget);
    });

    testWidgets('the presentation toggle swaps cards for dense rows',
        (tester) async {
      await _pumpVault(tester, seed: [_beat(status: BeatStatus.published)]);

      expect(find.byType(BeatCard), findsOneWidget);
      expect(find.byType(BeatListTile), findsNothing);

      await tester.tap(find.byKey(const Key('beat_view_list')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatListTile), findsOneWidget);
      expect(find.byType(BeatCard), findsNothing);
      expect(find.text('Amapiano • 112 BPM • F# Minor'), findsOneWidget);

      await tester.tap(find.byKey(const Key('beat_view_grid')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsOneWidget);
      expect(find.byType(BeatListTile), findsNothing);
    });

    testWidgets('the search field narrows the vault and offers a reset',
        (tester) async {
      await _pumpVault(
        tester,
        seed: [
          _beat(status: BeatStatus.published),
          _beat(
            id: 'beat_vault_2',
            title: 'Durban Midnight Rush',
            genre: 'Gqom',
          ),
        ],
      );

      expect(find.byType(BeatCard), findsNWidgets(2));

      await tester.enterText(find.byKey(const Key('beat_search')), 'gqom');
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsOneWidget);
      expect(find.text('Durban Midnight Rush'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('beat_search')), 'zzz');
      await tester.pumpAndSettle();

      expect(
        find.text('No beats found matching this filter'),
        findsOneWidget,
      );
      expect(find.text('Nothing matched "zzz"'), findsOneWidget);
      expect(find.byIcon(Icons.music_off_outlined), findsOneWidget);

      await tester.tap(find.byKey(const Key('beat_clear_filters')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsNWidgets(2));
      expect(
        find.text('No beats found matching this filter'),
        findsNothing,
      );
    });

    testWidgets('Reset Filters restores the genre dimension to All',
        (tester) async {
      final container = await _pumpVault(
        tester,
        seed: [
          _beat(status: BeatStatus.published),
          _beat(
            id: 'beat_vault_2',
            title: 'Durban Midnight Rush',
            genre: 'Gqom',
          ),
        ],
      );

      // No genre chip UI exists yet — drive the filter dimension directly.
      container.read(beatsVaultFilterProvider.notifier).state =
          container
              .read(beatsVaultFilterProvider)
              .copyWith(genreFilter: 'Maskandi');
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsNothing);
      expect(
        find.text('No beats found matching this filter'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('beat_clear_filters')));
      await tester.pumpAndSettle();

      expect(container.read(beatsVaultFilterProvider).genreFilter, 'All');
      expect(container.read(beatsVaultFilterProvider).hasActiveFilters, isFalse);
      expect(find.byType(BeatCard), findsNWidgets(2));
    });

    testWidgets('the status chips scope the vault projection', (tester) async {
      await _pumpVault(
        tester,
        seed: [
          _beat(status: BeatStatus.published),
          _beat(id: 'beat_vault_2', title: 'Sophiatown Bounce'),
        ],
      );

      await tester.tap(find.byKey(const Key('beat_status_chip_draft')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsOneWidget);
      expect(find.text('Sophiatown Bounce'), findsOneWidget);
      expect(find.text('Soshanguve Pulse'), findsNothing);

      await tester.tap(find.byKey(const Key('beat_status_chip_published')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsOneWidget);
      expect(find.text('Soshanguve Pulse'), findsOneWidget);

      await tester.tap(find.byKey(const Key('beat_status_chip_all')));
      await tester.pumpAndSettle();

      expect(find.byType(BeatCard), findsNWidgets(2));
    });

    testWidgets('the New Beat dialog authors a draft into the vault',
        (tester) async {
      final container = await _pumpVault(tester, seed: [_beat()]);

      await tester.tap(find.byKey(const Key('new_beat_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('beat_title_field')),
        'Ekasi Nights',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('beat_dialog_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Ekasi Nights'), findsOneWidget);

      final created = container.read(beatsProvider).first;
      expect(created.title, equals('Ekasi Nights'));
      expect(created.isDraft, isTrue);
      expect(
        created.previewAudioUrl,
        equals('https://cdn.vhunambi.com/beats/ekasi-nights.mp3'),
      );
    });

    testWidgets('publishing a draft routes through the confirmation sheet',
        (tester) async {
      final container = await _pumpVault(tester, seed: [_beat(stems: true)]);

      await tester.tap(find.byKey(const Key('beat_menu_beat_vault_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish to Marketplace'));
      await tester.pumpAndSettle();

      expect(find.text('Publish Beat to Live Marketplace'), findsOneWidget);

      await tester.tap(find.byKey(const Key('publish_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('is live on the marketplace'), findsOneWidget);
      expect(container.read(beatsProvider).single.isPublished, isTrue);
      expect(find.text('Published'), findsOneWidget);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_vault_1'),
        isTrue,
      );
    });

    testWidgets('a live beat switches back to draft instantly',
        (tester) async {
      final container = await _pumpVault(
        tester,
        seed: [_beat(status: BeatStatus.published, sales: const [10])],
      );

      await container
          .read(beatsProvider.notifier)
          .publishToMarket('beat_vault_1');
      await tester.pumpAndSettle();

      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_vault_1'),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('beat_menu_beat_vault_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch to Draft'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('switched back to draft'),
        findsOneWidget,
      );
      expect(container.read(beatsProvider).single.isDraft, isTrue);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_vault_1'),
        isFalse,
      );
    });

    testWidgets('deleting a beat asks for confirmation first', (tester) async {
      final container = await _pumpVault(tester, seed: [_beat()]);

      await tester.tap(find.byKey(const Key('beat_menu_beat_vault_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Beat?'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to delete'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('beat_delete_confirm')));
      await tester.pumpAndSettle();

      expect(container.read(beatsProvider), isEmpty);
      expect(find.text('Soshanguve Pulse'), findsNothing);
      expect(find.text('No beats yet'), findsOneWidget);
    });

    testWidgets('the stems sheet opens from the vault overflow menu',
        (tester) async {
      await _pumpVault(tester, seed: [_beat(stems: true)]);

      await tester.tap(find.byKey(const Key('beat_menu_beat_vault_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export Stems'));
      await tester.pumpAndSettle();

      expect(find.text('Stems Package (4/4)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stem_download_drums')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Drums stem queued for download'),
        findsOneWidget,
      );
    });
  });

  group('BeatDetailCockpitView', () {
    testWidgets('renders the hero, marketplace, stems and ledger cards',
        (tester) async {
      final container = await _pumpCockpit(
        tester,
        beat: _beat(
          status: BeatStatus.published,
          sales: const [10],
          auditionCount: 2,
        ),
      );

      // The title renders twice: the cockpit AppBar and the hero headline.
      expect(find.text('Soshanguve Pulse'), findsNWidgets(2));
      expect(find.byKey(const Key('cockpit_back')), findsOneWidget);
      expect(find.byKey(const Key('cockpit_artwork')), findsOneWidget);
      expect(find.byKey(const Key('cockpit_audition')), findsOneWidget);
      expect(find.byKey(const Key('cockpit_edit')), findsOneWidget);
      expect(find.byKey(const Key('cockpit_export_stems')), findsOneWidget);
      expect(
        find.byKey(const Key('cockpit_publish_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cockpit_export_stems_cta')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('stem_indicator_drums')), findsOneWidget);
      expect(find.byKey(const Key('sale_row_sale_0')), findsOneWidget);
      expect(find.text('+⚡ 10 Credits'), findsOneWidget);

      expect(container.read(beatsProvider).single.id, equals('beat_vault_1'));
    });

    testWidgets('publishing from the cockpit injects the marketplace listing',
        (tester) async {
      final container = await _pumpCockpit(tester, beat: _beat(stems: true));

      await tester.tap(find.byKey(const Key('cockpit_publish_toggle')));
      await tester.pumpAndSettle();

      expect(find.textContaining('is live on the marketplace'), findsOneWidget);
      expect(container.read(beatsProvider).single.isPublished, isTrue);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_vault_1'),
        isTrue,
      );
    });

    testWidgets('an unknown beat renders the unavailable fallback',
        (tester) async {
      await _pumpCockpit(tester, beat: null);

      expect(find.text('Beat unavailable'), findsOneWidget);
      expect(
        find.text('This beat is no longer in your vault.'),
        findsOneWidget,
      );
    });
  });

  group('LibraryView', () {
    testWidgets('the beats tab mounts the producer vault', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            beatRepositoryProvider.overrideWithValue(
              InMemoryBeatRepository(
                seed: [_beat(status: BeatStatus.published)],
              ),
            ),
            libraryCategoryProvider
                .overrideWith((ref) => LibraryCategory.beats),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LibraryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BeatsVaultView), findsOneWidget);
      expect(find.text('Soshanguve Pulse'), findsOneWidget);
    });
  });
}

/// Pumps [BeatsVaultView] on a deterministic desktop viewport and returns the
/// owning [ProviderContainer].
Future<ProviderContainer> _pumpVault(
  WidgetTester tester, {
  List<ProducerBeatEntity> seed = const <ProducerBeatEntity>[],
}) async {
  tester.view.physicalSize = const Size(1280, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        beatRepositoryProvider.overrideWithValue(
          InMemoryBeatRepository(seed: seed),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: BeatsVaultView()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The scope owns the container, so tearing the tree down cancels the player
  // position ticker before the framework's pending-timer assertion runs.
  return ProviderScope.containerOf(
    tester.element(find.byType(BeatsVaultView)),
  );
}
/// Pumps [BeatDetailCockpitView] for [beat]; a `null` seed exercises the
/// "beat unavailable" fallback route.
Future<ProviderContainer> _pumpCockpit(
  WidgetTester tester, {
  required ProducerBeatEntity? beat,
}) async {
  tester.view.physicalSize = const Size(1280, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        beatRepositoryProvider.overrideWithValue(
          InMemoryBeatRepository(
            seed: <ProducerBeatEntity>[?beat],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: BeatDetailCockpitView(beatId: beat?.id ?? 'ghost_beat'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(BeatDetailCockpitView)),
  );
}

ProducerBeatEntity _beat({
  String id = 'beat_vault_1',
  String title = 'Soshanguve Pulse',
  String genre = 'Amapiano',
  int bpm = 112,
  String key = 'F# Minor',
  int price = 10,
  BeatStatus status = BeatStatus.draft,
  bool stems = true,
  List<int> sales = const <int>[],
  int auditionCount = 0,
  DateTime? createdAt,
}) =>
    ProducerBeatEntity(
      id: id,
      title: title,
      genre: genre,
      bpm: bpm,
      musicalKey: key,
      priceInCredits: price,
      status: status,
      previewAudioUrl: 'https://cdn.vhunambi.com/beats/$id.mp3',
      stemPackage: stems
          ? const BeatStemPackage(
              drumsUrl: 'drums.wav',
              bassUrl: 'bass.wav',
              melodyUrl: 'melody.wav',
              otherUrl: 'fx.wav',
              isSeparated: true,
            )
          : const BeatStemPackage(),
      salesRecords: <BeatSaleRecord>[
        for (var index = 0; index < sales.length; index++)
          BeatSaleRecord(
            saleId: 'sale_$index',
            buyerId: 'creator_sipho',
            buyerHandle: '@sipho_beats',
            licenseTier: BeatLicenseTier.nonExclusiveCommercial,
            creditsEarned: sales[index],
            timestamp: DateTime(2026, 9, 24).add(Duration(hours: index)),
          ),
      ],
      auditionCount: auditionCount,
      createdAt: createdAt ?? DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 25),
    );

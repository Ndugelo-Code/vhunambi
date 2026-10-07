import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';
import 'package:vhunambi_client/features/beats/presentation/providers/beats_provider.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_card.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_form_dialog.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_list_tile.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_stats_banner.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/beat_status_badge.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/publish_beat_modal.dart';
import 'package:vhunambi_client/features/beats/presentation/widgets/stem_export_modal.dart';

/// T14.2 — Producer beats vault widget suite
/// (REQ-BEAT-15 / 16 / 18 / 19 / 20).
void main() {
  group('BeatStatusBadge', () {
    testWidgets('renders every lifecycle pill with its label and key',
        (tester) async {
      for (final status in BeatStatus.values) {
        await _pump(tester, BeatStatusBadge(status: status));

        expect(
          find.byKey(Key('beat_status_badge_${status.name}')),
          findsOneWidget,
        );
        expect(find.text(status.label), findsOneWidget);
      }
    });
  });

  group('BeatStatsBanner', () {
    testWidgets('renders the four producer analytics metrics', (tester) async {
      await _pump(
        tester,
        const BeatStatsBanner(
          stats: BeatsVaultStats(
            totalBeats: 3,
            publishedCount: 2,
            draftCount: 1,
            totalSalesCount: 4,
            totalCreditsEarned: 60,
          ),
        ),
      );

      expect(find.byKey(const Key('beat_stats_banner')), findsOneWidget);
      expect(find.text('PRODUCER BEATS COCKPIT'), findsOneWidget);
      expect(find.byKey(const Key('beat_stat_total')), findsOneWidget);
      expect(find.byKey(const Key('beat_stat_published')), findsOneWidget);
      expect(find.byKey(const Key('beat_stat_sales')), findsOneWidget);
      expect(find.byKey(const Key('beat_stat_credits')), findsOneWidget);

      expect(find.text('Total Beats'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Live on Market'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Licenses Sold'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Credits Earned'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
    });
  });

  group('BeatCard', () {
    testWidgets('renders artwork metadata, footer and every action',
        (tester) async {
      var taps = 0;
      var auditions = 0;
      var edits = 0;
      var publishes = 0;
      var exports = 0;
      var deletes = 0;

      await _pump(
        tester,
        SizedBox(
          width: 260,
          height: 320,
          child: BeatCard(
            beat: _beat(
              status: BeatStatus.published,
              stems: true,
              sales: const [10, 10],
            ),
            onTap: () => taps++,
            onAudition: () => auditions++,
            onEdit: () => edits++,
            onTogglePublish: () => publishes++,
            onExportStems: () => exports++,
            onDelete: () => deletes++,
          ),
        ),
      );

      expect(
        find.byKey(const Key('beat_card_beat_1')),
        findsOneWidget,
      );
      expect(find.text('Soshanguve Pulse'), findsOneWidget);
      expect(find.text('112 BPM'), findsOneWidget);
      expect(find.text('F# Minor'), findsOneWidget);
      expect(find.text('@you • 4/4 stems'), findsOneWidget);
      expect(find.text('⚡ 10 Cr • 2 Sold'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('beat_play_beat_1')));
      await tester.pump();
      expect(auditions, 1);

      await tester.tap(find.byKey(const Key('beat_card_beat_1')));
      await tester.pump();
      expect(taps, 1);

      await tester.tap(find.byKey(const Key('beat_menu_beat_1')));
      await tester.pumpAndSettle();
      expect(find.text('Switch to Draft'), findsOneWidget);
      await tester.tap(find.text('Switch to Draft'));
      await tester.pumpAndSettle();
      expect(publishes, 1);

      await tester.tap(find.byKey(const Key('beat_menu_beat_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Beat'));
      await tester.pumpAndSettle();
      expect(edits, 1);

      await tester.tap(find.byKey(const Key('beat_menu_beat_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export Stems'));
      await tester.pumpAndSettle();
      expect(exports, 1);

      await tester.tap(find.byKey(const Key('beat_menu_beat_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });

    testWidgets('an auditioning card swaps the play icon for a pause',
        (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 260,
          height: 320,
          child: BeatCard(
            beat: _beat(),
            isAuditioning: true,
            onTap: () {},
            onAudition: () {},
            onEdit: () {},
            onTogglePublish: () {},
            onExportStems: () {},
            onDelete: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Publish to Marketplace'), findsNothing);
    });
  });

  group('BeatListTile', () {
    testWidgets('renders the metadata row, price and publish switch',
        (tester) async {
      var toggles = 0;
      var auditions = 0;

      await _pump(
        tester,
        SizedBox(
          width: 900,
          child: BeatListTile(
            beat: _beat(status: BeatStatus.published, sales: const [10]),
            onTap: () {},
            onAudition: () => auditions++,
            onEdit: () {},
            onTogglePublish: () => toggles++,
            onExportStems: () {},
            onDelete: () {},
          ),
        ),
      );

      expect(
        find.byKey(const Key('beat_tile_beat_1')),
        findsOneWidget,
      );
      expect(find.text('Soshanguve Pulse'), findsOneWidget);
      expect(find.text('Amapiano • 112 BPM • F# Minor'), findsOneWidget);
      expect(find.text('⚡ 10 Credits'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);

      final toggle = tester.widget<Switch>(
        find.byKey(const Key('beat_publish_switch_beat_1')),
      );
      expect(toggle.value, isTrue);

      await tester.tap(find.byKey(const Key('beat_publish_switch_beat_1')));
      await tester.pump();
      expect(toggles, 1);

      await tester.tap(find.byKey(const Key('beat_tile_play_beat_1')));
      await tester.pump();
      expect(auditions, 1);
    });

    testWidgets('the row menu publishes a draft beat', (tester) async {
      var publishes = 0;
      var exports = 0;

      await _pump(
        tester,
        SizedBox(
          width: 900,
          child: BeatListTile(
            beat: _beat(),
            onTap: () {},
            onAudition: () {},
            onEdit: () {},
            onTogglePublish: () => publishes++,
            onExportStems: () => exports++,
            onDelete: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('beat_tile_menu_beat_1')));
      await tester.pumpAndSettle();
      expect(find.text('Publish to Marketplace'), findsOneWidget);

      await tester.tap(find.text('Publish to Marketplace'));
      await tester.pumpAndSettle();
      expect(publishes, 1);

      await tester.tap(find.byKey(const Key('beat_tile_menu_beat_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export Stems'));
      await tester.pumpAndSettle();
      expect(exports, 1);
    });
  });

  group('BeatFormDialog', () {
    testWidgets('blocks empty titles and returns the authored payload',
        (tester) async {
      BeatFormResult? result;
      await _pumpDialogHost(
        tester,
        (_) => BeatFormDialog(onSubmitted: (value) => result = value),
      );

      expect(find.text('Configure Beat Listing'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('beat_dialog_submit')))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('beat_title_field')),
        'Ekasi Nights',
      );
      await tester.enterText(find.byKey(const Key('beat_bpm_field')), '300');
      await tester.enterText(
        find.byKey(const Key('beat_tags_field')),
        'Log Drum, log drum, Soulful',
      );
      await tester.pump();

      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('beat_dialog_submit')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('beat_status_publish')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('beat_dialog_submit')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.title, equals('Ekasi Nights'));
      expect(result!.genre, equals('Amapiano'));
      expect(result!.bpm, equals(260));
      expect(result!.musicalKey, equals('F# Minor'));
      expect(result!.tags, equals(const ['Log Drum', 'Soulful']));
      expect(result!.priceInCredits, equals(10));
      expect(
        result!.licenseTier,
        equals(BeatLicenseTier.nonExclusiveCommercial),
      );
      expect(result!.status, equals(BeatStatus.published));
      expect(find.text('Configure Beat Listing'), findsNothing);
    });

    testWidgets('edit mode pre-populates the listing and saves changes',
        (tester) async {
      BeatFormResult? result;
      await _pumpDialogHost(
        tester,
        (_) => BeatFormDialog(
          initial: _beat(status: BeatStatus.published, price: 30),
          onSubmitted: (value) => result = value,
        ),
      );

      expect(find.text('Edit Beat Listing'), findsOneWidget);
      expect(find.text('Save Beat'), findsOneWidget);
      expect(find.text('Soshanguve Pulse'), findsOneWidget);
      expect(find.text('⚡ 30 Credits'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('beat_title_field')),
        'Bacardi Bounce',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('beat_dialog_submit')));
      await tester.pumpAndSettle();

      expect(result!.title, equals('Bacardi Bounce'));
      expect(result!.priceInCredits, equals(30));
      expect(result!.status, equals(BeatStatus.published));
    });

    testWidgets('changing the licensing tier syncs the price preset',
        (tester) async {
      BeatFormResult? result;
      await _pumpDialogHost(
        tester,
        (_) => BeatFormDialog(onSubmitted: (value) => result = value),
      );

      await tester.enterText(
        find.byKey(const Key('beat_title_field')),
        'Sync Ready',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('beat_tier_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync License').last);
      await tester.pumpAndSettle();

      expect(find.text('⚡ 30 Credits'), findsOneWidget);

      await tester.tap(find.byKey(const Key('beat_dialog_submit')));
      await tester.pumpAndSettle();

      expect(result!.licenseTier, equals(BeatLicenseTier.syncLicense));
      expect(result!.priceInCredits, equals(30));
    });

    testWidgets('tap tempo derives the BPM from the tap gap', (tester) async {
      var now = DateTime(2026, 9, 26, 12);
      await _pumpDialogHost(
        tester,
        (_) => BeatFormDialog(onSubmitted: (_) {}, clock: () => now),
      );

      await tester.enterText(find.byKey(const Key('beat_bpm_field')), '90');
      await tester.pump();

      await tester.tap(find.byKey(const Key('beat_tap_tempo')));
      await tester.pump();
      now = now.add(const Duration(milliseconds: 1000));
      await tester.tap(find.byKey(const Key('beat_tap_tempo')));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('beat_bpm_field')),
      );
      expect(field.controller!.text, equals('60'));
    });
  });

  group('PublishBeatModal', () {
    testWidgets('explains the licensing terms and can keep the draft',
        (tester) async {
      var confirmed = 0;
      await _pumpSheetHost(
        tester,
        (_) => PublishBeatModal(
          beat: _beat(status: BeatStatus.published, sales: const [10]),
          onConfirm: () => confirmed++,
        ),
      );

      expect(find.text('Publish Beat to Live Marketplace'), findsOneWidget);
      expect(
        find.text('Soshanguve Pulse (Amapiano • 112 BPM)'),
        findsOneWidget,
      );
      expect(find.text('⚡ 10 Credits'), findsOneWidget);
      expect(
        find.text('100% of credits credited on each license'),
        findsOneWidget,
      );
      expect(find.text('180 second preview streaming enabled'), findsOneWidget);
      expect(find.text('Visible immediately at /market'), findsOneWidget);

      await tester.tap(find.byKey(const Key('publish_keep_draft_button')));
      await tester.pumpAndSettle();

      expect(confirmed, 0);
      expect(find.text('Publish Beat to Live Marketplace'), findsNothing);
    });

    testWidgets('Confirm & Publish fires the callback and closes the sheet',
        (tester) async {
      var confirmed = 0;
      await _pumpSheetHost(
        tester,
        (_) => PublishBeatModal(beat: _beat(), onConfirm: () => confirmed++),
      );

      await tester.tap(find.byKey(const Key('publish_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmed, 1);
      expect(find.byKey(const Key('publish_confirm_button')), findsNothing);
    });
  });

  group('StemExportModal', () {
    testWidgets('lists four ready stems and simulates stem actions',
        (tester) async {
      final auditions = <String>[];
      final downloads = <String>[];
      var bundles = 0;

      await _pumpSheetHost(
        tester,
        (_) => StemExportModal(
          beat: _beat(stems: true),
          onAuditionStem: auditions.add,
          onDownloadStem: downloads.add,
          onDownloadBundle: () => bundles++,
        ),
      );

      expect(find.text('Stems Package (4/4)'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(4));
      for (final slug in const ['drums', 'bass', 'melody', 'other']) {
        expect(find.byKey(Key('stem_row_$slug')), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('stem_audition_drums')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('stem_download_melody')));
      await tester.pump();

      expect(auditions, equals(const ['Drums']));
      expect(downloads, equals(const ['Melody']));

      await tester.tap(find.byKey(const Key('stem_download_bundle')));
      await tester.pumpAndSettle();

      expect(bundles, 1);
      expect(find.text('Stems Package (4/4)'), findsNothing);
    });

    testWidgets('unseparated stems render disabled transfer controls',
        (tester) async {
      await _pumpSheetHost(tester, (_) => StemExportModal(beat: _beat()));

      expect(find.text('Stems Package (0/4)'), findsOneWidget);
      expect(find.text('Not separated yet'), findsNWidgets(4));

      final audition = tester.widget<IconButton>(
        find.byKey(const Key('stem_audition_drums')),
      );
      final download = tester.widget<IconButton>(
        find.byKey(const Key('stem_download_other')),
      );

      expect(audition.onPressed, isNull);
      expect(download.onPressed, isNull);
    });
  });
}

/// Pumps [child] on a deterministic desktop viewport inside the dark theme.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 1024),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens [builder] as an `AlertDialog` route so it can pop itself safely.
Future<void> _pumpDialogHost(WidgetTester tester, WidgetBuilder builder) {
  return _pumpRouteHost(
    tester,
    (context) => showDialog<void>(context: context, builder: builder),
  );
}

/// Opens [builder] as a transparent modal bottom sheet route.
Future<void> _pumpSheetHost(WidgetTester tester, WidgetBuilder builder) {
  return _pumpRouteHost(
    tester,
    (context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: builder,
    ),
  );
}

Future<void> _pumpRouteHost(
  WidgetTester tester,
  void Function(BuildContext context) open,
) async {
  tester.view.physicalSize = const Size(1280, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open-route'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-route'));
  await tester.pumpAndSettle();
}

ProducerBeatEntity _beat({
  String id = 'beat_1',
  String title = 'Soshanguve Pulse',
  String genre = 'Amapiano',
  int bpm = 112,
  String key = 'F# Minor',
  int price = 10,
  BeatStatus status = BeatStatus.draft,
  bool stems = false,
  List<int> sales = const <int>[],
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
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 25),
    );

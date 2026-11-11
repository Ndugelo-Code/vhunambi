import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/beats/presentation/views/beats_vault_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/data/services/beat_delivery_unpacker_service.dart';
import 'package:vhunambi_client/features/marketplace/data/services/certificate_share_exporter.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/views/marketplace_view.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

Future<void> _syncDiskWriter(String path, Uint8List bytes) async {
  final file = File(path);
  if (!file.parent.existsSync()) {
    file.parent.createSync(recursive: true);
  }
  file.writeAsBytesSync(bytes, flush: true);
}

void main() {
  group('Phase 58 Multi-Tier Checkout, Deed Sheet & Stems Drawer Widget Tests', () {
    late Directory tempDir;
    late OfflineStorageService offlineStorage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_p58_widget_');
      offlineStorage = OfflineStorageService(
        customVaultDirectory: tempDir.path,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'Tier switching, low-coin Top Up guard, live topup recovery, Exclusive checkout & Deed Sheet',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final premiumBeat = BeatListingEntity(
          id: 'beat_p58_premium',
          title: 'Venda Gold Exclusive',
          producerId: 'creator_sipho',
          producerName: 'Sipho',
          producerHandle: '@sipho_beats',
          genre: 'Amapiano',
          bpm: 114,
          musicalKey: 'E Minor',
          priceInCredits: 10, // 50 / 150 / 300 Coins
          previewAudioUrl: 'https://cdn.vhunambi.com/beats/venda-gold.mp3',
          createdAt: DateTime.now().add(const Duration(minutes: 5)),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              offlineStorageServiceProvider.overrideWithValue(offlineStorage),
              beatDeliveryUnpackerProvider.overrideWithValue(
                BeatDeliveryUnpackerService(
                  offlineStorage: offlineStorage,
                  allowNetworkFetch: false,
                  fileWriter: _syncDiskWriter,
                ),
              ),
              certificateShareExporterProvider.overrideWithValue(
                CertificateShareExporter(
                  offlineStorage: offlineStorage,
                  fileWriter: _syncDiskWriter,
                  platformSharer: (_, {subject, text}) async {},
                ),
              ),
              syncOutboxServiceProvider.overrideWithValue(
                SyncOutboxService(isInMemoryOnly: true),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MarketplaceView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MarketplaceView)),
        );
        container
            .read(marketplaceBeatsProvider.notifier)
            .addListing(premiumBeat);
        await tester.pumpAndSettle();

        // Open modal on newest beat ("Venda Gold Exclusive")
        await tester.tap(find.text('License Beat').first);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('license_tier_card_basicMp3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('license_tier_card_premiumWav')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('license_tier_card_exclusiveStem')),
          findsOneWidget,
        );

        // Expand full legal terms
        await tester.tap(find.byKey(const Key('license_expand_terms_btn')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('VHUNAMBI SOVEREIGN BEAT LICENSE DEED'),
          findsOneWidget,
        );

        // Select Exclusive Stem tier (300 Coins > 250 default Coins -> deficit 50)
        await tester.tap(
          find.byKey(const Key('license_tier_card_exclusiveStem')),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Insufficient Coins: Short by 50 Coins'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('checkout_topup_btn')), findsOneWidget);

        final disabledBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('checkout_confirm_btn')),
        );
        expect(disabledBtn.onPressed, isNull);

        // Simulate topping up +100 Coins -> balance becomes 350 Coins -> confirm enables
        container.read(creatorWalletProvider.notifier).topUpCoins(100);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Remaining balance after checkout: 50 Coins'),
          findsOneWidget,
        );
        final confirmBtn = find.byKey(const Key('checkout_confirm_btn'));
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Verified receipt appears & beat is removed from Marketplace
        expect(find.text('License Verified & Unpacked'), findsOneWidget);
        expect(find.byKey(const Key('checkout_view_cert_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('checkout_open_vault_btn')),
          findsOneWidget,
        );
        expect(container.read(creatorWalletProvider).userCoinsBalance, 50);
        expect(
          container
              .read(filteredBeatsProvider)
              .any((b) => b.id == 'beat_p58_premium'),
          isFalse,
        );

        // Open Cryptographic Ownership Deed Sheet
        await tester.tap(find.byKey(const Key('checkout_view_cert_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Sovereign License Deed'), findsOneWidget);
        expect(find.text('VERIFIED'), findsOneWidget);

        await tester.tap(find.byKey(const Key('license_cert_verify_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('license_cert_share_btn')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Exported legal deed & JSON'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BeatsVaultView renders 4-Stem Drawer button and lists isolated WAV stems',
      (WidgetTester tester) async {
        final trackWithStems = LibraryTrack(
          id: 'market_beat_stems_99',
          title: 'Pretoria Private School',
          creatorName: 'Kelvin Vibe',
          genre: 'Amapiano',
          language: 'Instrumental',
          durationSeconds: 180,
          remoteAudioUrl: 'https://cdn.vhunambi.com/beats/pretoria.mp3',
          masterAudioFilePath: '${tempDir.path}/master_44k1.wav',
          stemPaths: <String, String>{
            'drums': '${tempDir.path}/drums_44k1.wav',
            'bass': '${tempDir.path}/bass_44k1.wav',
            'melody': '${tempDir.path}/melody_44k1.wav',
            'other': '${tempDir.path}/other_44k1.wav',
          },
          createdAt: DateTime(2026, 11, 9),
          licenseType: 'Exclusive Stem License',
          syncStatus: TrackSyncStatus.cachedLocally,
          isInstrumental: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: BeatsVaultView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(BeatsVaultView)),
        );
        container
            .read(libraryTracksProvider.notifier)
            .upsertLicensedTrack(trackWithStems);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('beats_vault_mode_licensed')));
        await tester.pumpAndSettle();

        final stemsBtn = find.byKey(
          const Key('licensed_beat_stems_btn_market_beat_stems_99'),
        );
        expect(stemsBtn, findsOneWidget);
        await tester.tap(stemsBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Isolated 44.1 kHz Stems'), findsOneWidget);
        expect(find.text('Drums Stem (44.1 kHz WAV)'), findsOneWidget);
        expect(find.text('Bass Stem (44.1 kHz WAV)'), findsOneWidget);
        expect(find.text('Melody Stem (44.1 kHz WAV)'), findsOneWidget);
        expect(find.text('Other Stem (44.1 kHz WAV)'), findsOneWidget);
      },
    );
  });
}

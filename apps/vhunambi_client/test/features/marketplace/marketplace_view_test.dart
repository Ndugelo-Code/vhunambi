import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/data/services/beat_delivery_unpacker_service.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/views/marketplace_view.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/beat_card.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/marketplace_empty_state.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/marketplace_top_bar.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

Future<void> _syncDiskWriter(String path, Uint8List bytes) async {
  final file = File(path);
  if (!file.parent.existsSync()) {
    file.parent.createSync(recursive: true);
  }
  file.writeAsBytesSync(bytes, flush: true);
}

Future<void> _pumpMarketplace(
  WidgetTester tester, {
  Size size = const Size(1280, 1700),
  VoidCallback? onNavigateToLibrary,
  OfflineStorageService? offlineStorage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (offlineStorage != null) ...[
          offlineStorageServiceProvider.overrideWithValue(offlineStorage),
          beatDeliveryUnpackerProvider.overrideWithValue(
            BeatDeliveryUnpackerService(
              offlineStorage: offlineStorage,
              allowNetworkFetch: false,
              fileWriter: _syncDiskWriter,
            ),
          ),
        ],
        syncOutboxServiceProvider.overrideWithValue(
          SyncOutboxService(isInMemoryOnly: true),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MarketplaceView(onNavigateToLibrary: onNavigateToLibrary),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MarketplaceView)));

void main() {

  testWidgets('Desktop marketplace renders header, banner and listings',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester);

    // Unified Coins Top Bar (Phase 58 / STD-UIUX-001)
    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text(MarketplaceTopBar.searchHint), findsOneWidget);
    expect(find.text('250 Coins'), findsOneWidget);

    // Page header + filter trigger
    expect(find.text('Beats Marketplace'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('6 listings available'), findsOneWidget);

    // Seller monetization banner (REQ-MKT-02)
    expect(find.text('Sell your beats'), findsOneWidget);
    expect(find.text('Go to Library'), findsOneWidget);

    // Beat listing grid (REQ-MKT-03)
    expect(find.byType(BeatCard), findsNWidgets(6));
    expect(find.text('Township Heat'), findsOneWidget);
    expect(find.text('112 BPM'), findsOneWidget);
    expect(find.text('F# Minor'), findsOneWidget);
    expect(find.text('⚡ 5 Credits'), findsNWidgets(6));
    expect(find.text('25 Coins'), findsNWidgets(6));
    expect(find.text('License Beat'), findsNWidgets(6));
    expect(find.text('@sipho_beats'), findsOneWidget);
  });

  testWidgets('Mobile marketplace keeps the compact top bar and 2-column grid',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester, size: const Size(420, 1700));

    expect(find.text('VHUNAMBI'), findsNothing);
    expect(find.text(MarketplaceTopBar.searchHint), findsOneWidget);
    expect(find.text('250 Coins'), findsOneWidget);
    expect(find.text('Beats Marketplace'), findsOneWidget);
    expect(find.byType(BeatCard), findsNWidgets(6));
  });

  testWidgets('Seller callout routes to the Library tab',
      (WidgetTester tester) async {
    var libraryRequests = 0;
    await _pumpMarketplace(
      tester,
      onNavigateToLibrary: () => libraryRequests++,
    );

    await tester.tap(find.text('Go to Library'));
    await tester.pumpAndSettle();

    expect(libraryRequests, 1);
  });

  testWidgets('Audition button streams the beat preview into the player',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester);
    final container = _containerOf(tester);
    final firstCard = find.byType(BeatCard).first;

    await tester.tap(
      find.descendant(
        of: firstCard,
        matching: find.byIcon(AppIcons.play),
      ),
    );
    await tester.pumpAndSettle();

    final player = container.read(playerStateProvider);
    expect(player.currentTrack?.id, 'beat_township_heat');
    expect(player.currentTrack?.title, 'Township Heat');
    expect(player.isPlaying, isTrue);
    expect(
      find.descendant(
        of: firstCard,
        matching: find.byIcon(AppIcons.pause),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Licensing a beat deducts coins, unpacks WAV and stores certificate in vault',
      (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('vhunambi_mkt_view_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final offlineStorage = OfflineStorageService(
      customVaultDirectory: tempDir.path,
    );

    await _pumpMarketplace(tester, offlineStorage: offlineStorage);
    final container = _containerOf(tester);

    expect(container.read(marketplaceCreditsProvider), 10);
    expect(container.read(creatorWalletProvider).userCoinsBalance, 250);
    final vaultBefore = container.read(libraryTracksProvider).length;

    await tester.tap(find.text('License Beat').first);
    await tester.pumpAndSettle();

    // Multi-tier commercial licensing modal (Phase 58)
    expect(find.byKey(const Key('license_tier_card_basicMp3')), findsOneWidget);
    expect(find.byKey(const Key('license_tier_card_premiumWav')), findsOneWidget);
    expect(find.text('Remaining balance after checkout: 225 Coins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout_confirm_btn')));
    await tester.pumpAndSettle();

    expect(container.read(creatorWalletProvider).userCoinsBalance, 225);
    expect(container.read(marketplaceCreditsProvider), 45);
    expect(find.text('225 Coins'), findsOneWidget);
    expect(find.text('License Verified & Unpacked'), findsOneWidget);

    final vault = container.read(libraryTracksProvider);
    expect(vault.length, vaultBefore + 1);
    final licensed = vault.firstWhere((track) => track.title == 'Township Heat');
    expect(licensed.creatorName, 'Sipho');
    expect(licensed.isInstrumental, isTrue);
    expect(licensed.licenseType, 'Basic MP3');
    expect(licensed.licenseCertificateId, startsWith('CERT-VHB-'));
    expect(licensed.isOfflineAvailable, isTrue);
    expect(File(licensed.effectiveAudioPath!).existsSync(), isTrue);
  });

  testWidgets('Filter sheet scopes listings and the empty state recovers',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    // Filter sheet (REQ-MKT-05)
    expect(find.text('Filter beats'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.text('BPM range: 70 – 160'), findsOneWidget);
    expect(find.text('Max price: 20 credits'), findsOneWidget);

    await tester.tap(find.text('Gqom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(BeatCard), findsOneWidget);
    expect(find.text('Durban Midnight Bass'), findsOneWidget);
    expect(find.text('1 listing available'), findsOneWidget);

    // Search with no matches renders the universal empty state
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byType(MarketplaceEmptyState), findsOneWidget);
    expect(find.text('No beats found'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byType(MarketplaceEmptyState), findsNothing);
    expect(find.byType(BeatCard), findsNWidgets(6));
    expect(find.text('6 listings available'), findsOneWidget);
  });
}

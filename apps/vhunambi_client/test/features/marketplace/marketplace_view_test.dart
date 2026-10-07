import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/views/marketplace_view.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/beat_card.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/marketplace_empty_state.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/marketplace_top_bar.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/pwa_install_dock.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';

Future<void> _pumpMarketplace(
  WidgetTester tester, {
  Size size = const Size(1280, 1700),
  VoidCallback? onNavigateToLibrary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
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

    // Top bar (REQ-MKT-01)
    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text(MarketplaceTopBar.searchHint), findsOneWidget);
    expect(find.text('10 songs left'), findsOneWidget);

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
    expect(find.text('License Beat'), findsNWidgets(6));
    expect(find.text('@sipho_beats'), findsOneWidget);

    // Persistent PWA install dock (REQ-MKT-06)
    expect(find.byType(PwaInstallDock), findsOneWidget);
    expect(find.text('Install VHUNAMBI'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('How?'), findsOneWidget);
  });

  testWidgets('Mobile marketplace keeps the compact top bar and 2-column grid',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester, size: const Size(420, 1700));

    expect(find.text('VHUNAMBI'), findsNothing);
    expect(find.text(MarketplaceTopBar.searchHint), findsOneWidget);
    expect(find.text('10 songs left'), findsOneWidget);
    expect(find.text('Beats Marketplace'), findsOneWidget);
    expect(find.byType(BeatCard), findsNWidgets(6));
    expect(find.text('Install VHUNAMBI'), findsOneWidget);
  });

  testWidgets('PWA dock is dismissed by Not now', (WidgetTester tester) async {
    await _pumpMarketplace(tester);
    expect(find.byType(PwaInstallDock), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Install VHUNAMBI'), findsNothing);
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
        matching: find.byIcon(Icons.play_arrow_rounded),
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
        matching: find.byIcon(Icons.pause_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Licensing a beat deducts credits and stores it in the vault',
      (WidgetTester tester) async {
    await _pumpMarketplace(tester);
    final container = _containerOf(tester);

    expect(container.read(marketplaceCreditsProvider), 10);
    final vaultBefore = container.read(libraryTracksProvider).length;

    await tester.tap(find.text('License Beat').first);
    await tester.pumpAndSettle();

    // Commercial licensing modal (REQ-MKT-04)
    expect(find.text('Non-Exclusive Commercial licence'), findsOneWidget);
    expect(find.text('License for 5 Credits'), findsOneWidget);
    expect(find.text('Balance after licensing: 5 credits'), findsOneWidget);
    expect(
      find.text('Non-exclusive commercial sync rights'),
      findsOneWidget,
    );

    await tester.tap(find.text('License for 5 Credits'));
    await tester.pumpAndSettle();

    expect(container.read(marketplaceCreditsProvider), 5);
    expect(find.text('5 songs left'), findsOneWidget);
    expect(find.text('License for 5 Credits'), findsNothing);

    final vault = container.read(libraryTracksProvider);
    expect(vault.length, vaultBefore + 1);
    final licensed = vault.firstWhere((track) => track.title == 'Township Heat');
    expect(licensed.creatorName, 'Sipho');
    expect(licensed.isInstrumental, isTrue);
    expect(licensed.licenseType, 'Non-Exclusive Commercial');
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

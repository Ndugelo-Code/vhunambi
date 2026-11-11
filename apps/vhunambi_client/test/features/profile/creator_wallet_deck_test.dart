import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_wallet_deck.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

void main() {
  testWidgets('renders lifetime earnings, coins, and supporter ranks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: CreatorWalletDeck()),
          ),
        ),
      ),
    );

    expect(find.text('Creator Wallet'), findsOneWidget);
    expect(find.text('Lifetime Earnings'), findsOneWidget);
    expect(find.text('R1,420.00'), findsOneWidget);
    expect(find.textContaining('4,750 🪙'), findsOneWidget);
    expect(find.text('Top Supporters'), findsOneWidget);
    expect(find.text('Recent Gifts'), findsOneWidget);
  });

  testWidgets('payout button opens the method dialog and processes payout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(child: CreatorWalletDeck()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('wallet_payout_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Cash Out Creator Royalties'), findsOneWidget);
    await tester.tap(find.byKey(const Key('payout_rail_ozow')));
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const Key('payout_confirm_btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Full balance withdrawn -> earnings reset toward zero.
    expect(container.read(creatorWalletProvider).creatorEarnedZar, 0.0);
    expect(
      container.read(creatorWalletProvider).payoutStatusMessage,
      contains('Ozow'),
    );

    // Drain the payout SnackBar timer.
    await tester.pump(const Duration(seconds: 5));
  });
}

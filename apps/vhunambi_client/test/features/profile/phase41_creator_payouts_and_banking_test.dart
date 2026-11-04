import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_top_bar_kit.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_app_bar.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/payout_details_sheet.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 41: Creator Sovereign Royalty Payouts & Banking KYC Sheet', () {
    test('REQ-PAYOUT-MODEL-01: CreatorBankingDetails masks account and has branch directory', () {
      const details = CreatorBankingDetails(
        bankName: 'Capitec Bank',
        accountHolder: 'Ndugelo Musician',
        accountNumber: '1092837465',
        branchCode: '470010',
      );

      expect(details.maskedAccount, '•••• 7465');
      expect(kSouthAfricanUniversalBranchCodes['Capitec Bank'], '470010');
      expect(kSouthAfricanUniversalBranchCodes['FNB'], '250655');
      expect(kSouthAfricanUniversalBranchCodes['Standard Bank'], '051001');
    });

    test('REQ-PAYOUT-DISPATCH-01: requestBankingPayout deducts balance and posts notification', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialEarned = container.read(creatorWalletProvider).creatorEarnedZar;
      expect(initialEarned, greaterThanOrEqualTo(50.0));

      const details = CreatorBankingDetails(
        bankName: 'FNB',
        accountHolder: 'Ndugelo',
        accountNumber: '62819283746',
        branchCode: '250655',
      );

      final success = await container
          .read(creatorWalletProvider.notifier)
          .requestBankingPayout(amountZar: 200.0, bankingDetails: details);

      expect(success, isTrue);

      final newEarned = container.read(creatorWalletProvider).creatorEarnedZar;
      expect(newEarned, initialEarned - 200.0);

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Royalty Payout Initiated' &&
            n.category == NotificationCategory.system &&
            n.message.contains('FNB')),
        isTrue,
      );
    });

    testWidgets('REQ-PAYOUT-UI-01 & 02: PayoutDetailsSheet renders form and validates fields', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: PayoutDetailsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cash Out Creator Royalties'), findsOneWidget);
      expect(find.text('Select Bank'), findsOneWidget);
      expect(find.byKey(const Key('payout_account_holder_input')), findsOneWidget);
      expect(find.byKey(const Key('payout_account_number_input')), findsOneWidget);
      expect(find.byKey(const Key('payout_branch_code_input')), findsOneWidget);
      expect(find.byKey(const Key('payout_confirm_btn')), findsOneWidget);

      // Verify branch code is initially auto-populated for Capitec
      expect(find.text('470010'), findsOneWidget);

      // Submit payout
      await tester.tap(find.byKey(const Key('payout_confirm_btn')));
      await tester.pumpAndSettle();

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) => n.title == 'Royalty Payout Initiated'),
        isTrue,
      );
    });

    testWidgets('REQ-NAV-AVATAR-01: LibraryAppBar renders VhunambiUserAvatarButton on mobile', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: LibraryAppBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VhunambiUserAvatarButton), findsOneWidget);
    });
  });
}


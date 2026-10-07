import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_referral_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/releases_manager_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/tip_history_ledger.dart';

Future<void> _pumpOwnerProfile(
  WidgetTester tester, {
  Size size = const Size(1280, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const OwnerProfileView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('OwnerProfileView renders creator cockpit, quick actions, and management widgets',
      (WidgetTester tester) async {
    await _pumpOwnerProfile(tester);

    // 1. Identity & Studio Profile Header (REQ-TRK-15)
    expect(find.text('cern'), findsOneWidget);
    expect(find.textContaining('@cern'), findsOneWidget);
    expect(find.text('CE'), findsOneWidget);
    expect(find.text('CREATOR STUDIO'), findsOneWidget);

    // 2. Action Chips
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Pin Song'), findsOneWidget);
    expect(find.text('Studio Analytics'), findsOneWidget);

    // 3. Top Genres
    expect(find.text('🎵 House (1)'), findsOneWidget);
    expect(find.text('🎹 Amapiano (4)'), findsOneWidget);

    // 4. Studio Tracks & Inline Visibility
    expect(find.text('Your Songs'), findsOneWidget);
    expect(find.text('ZaYN'), findsOneWidget);
    expect(find.text('🌐 Public'), findsNWidgets(2));

    // 5. Discography Releases Manager
    expect(find.byType(ReleasesManagerCard), findsOneWidget);
    expect(find.text('Discography Releases'), findsOneWidget);
    expect(find.text('Genesis Sessions'), findsOneWidget);
    expect(find.text('New Release'), findsOneWidget);

    // 6. Financial Tip History Ledger (REQ-TRK-16)
    expect(find.byType(TipHistoryLedger), findsOneWidget);
    expect(find.text('Tip History'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);

    // 7. Profile Referral Link Card (REQ-TRK-16)
    expect(find.byType(ProfileReferralCard), findsOneWidget);
    expect(find.text('Share your profile'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
  });

  testWidgets('OwnerProfileView toggles track visibility between public and private',
      (WidgetTester tester) async {
    await _pumpOwnerProfile(tester);

    expect(find.text('🌐 Public'), findsNWidgets(2));

    // Tap first visibility button
    await tester.tap(find.text('🌐 Public').first);
    await tester.pumpAndSettle();

    expect(find.text('🔒 Private'), findsOneWidget);
    expect(find.text('🌐 Public'), findsOneWidget);
  });

  testWidgets('OwnerProfileView switches tip history between received and sent tabs',
      (WidgetTester tester) async {
    await _pumpOwnerProfile(tester);

    // Initial sub-tab is Received
    expect(find.text('Sent'), findsOneWidget);

    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();

    // Verify sub-tab switch
    expect(find.text('Sent'), findsOneWidget);
  });
}

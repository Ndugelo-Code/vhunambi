import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_reel_thumbnail_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(String artistId) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: ArtistProfileView(artistId: artistId),
        ),
      );

  Future<void> pumpTabs(WidgetTester tester, {String artistId = 'fifi'}) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(host(artistId));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the tri-modal tab bar (Clips / Music / Beats)',
      (tester) async {
    await pumpTabs(tester);

    expect(find.text('Clips'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Beats'), findsOneWidget);
  });

  testWidgets('Clips tab shows the creator reel grid', (tester) async {
    await pumpTabs(tester);

    // Fifi has seeded clips under creator_fifi.
    expect(find.byType(CreatorReelThumbnailCard), findsWidgets);
  });

  testWidgets('switching to Music tab reveals Top Songs & Releases',
      (tester) async {
    await pumpTabs(tester);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(find.text('Top Songs'), findsOneWidget);
    expect(find.text('Releases'), findsOneWidget);
  });

  testWidgets('switching to Beats tab reveals license card & supporters',
      (tester) async {
    await pumpTabs(tester);

    await tester.tap(find.text('Beats'));
    await tester.pumpAndSettle();

    expect(find.text('Beats & Stems'), findsOneWidget);
    expect(find.text('Top Supporters'), findsOneWidget);
  });

  testWidgets('Follow button toggles reactively', (tester) async {
    await pumpTabs(tester);

    expect(find.text('Follow'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
  });
}

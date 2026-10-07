import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_header_section.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_top_bar.dart';
import 'package:vhunambi_client/main.dart';

void main() {
  testWidgets('VhunambiApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: VhunambiApp(initialHome: RootShell()),
      ),
    );

    // The shell boots into the Explore discovery feed (tab index 1). Per the
    // Blueprint 01 mobile header contract the compact top bar renders the brand
    // emblem without the `VHUNAMBI` wordmark, so the boot assertion targets the
    // discovery chrome instead.
    expect(find.byType(MobileExploreTopBar), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    // Explore header title (the mobile bottom dock also labels the tab
    // 'Explore', so the assertion is scoped to the header section).
    expect(
      find.descendant(
        of: find.byType(ExploreHeaderSection),
        matching: find.text('Explore'),
      ),
      findsOneWidget,
    );
  });
}

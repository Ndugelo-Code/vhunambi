import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    await tester.pumpAndSettle();

    // The shell boots into the Explore discovery feed (tab index 1).
    expect(find.byType(MobileExploreTopBar), findsOneWidget);
    expect(find.byKey(const Key('explore_transient_title_pill')), findsOneWidget);
  });
}

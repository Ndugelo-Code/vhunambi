import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/pulsing_aura_container.dart';

void main() {
  testWidgets('PulsingAuraContainer renders child with and without pulsing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingAuraContainer(
            isPulsing: false,
            child: Text('Aura Content'),
          ),
        ),
      ),
    );

    expect(find.text('Aura Content'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingAuraContainer(
            isPulsing: true,
            child: Text('Aura Content'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aura Content'), findsOneWidget);
  });

  testWidgets('PulsingAuraContainer transitions between pulsing states cleanly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingAuraContainer(
            isPulsing: true,
            child: Text('Active Aura'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingAuraContainer(
            isPulsing: false,
            child: Text('Active Aura'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Active Aura'), findsOneWidget);
  });
}

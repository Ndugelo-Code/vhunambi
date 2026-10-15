import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/tactile_pressable.dart';

void main() {
  testWidgets('TactilePressable renders child and responds to onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TactilePressable(
            onTap: () => tapped = true,
            child: const Text('Press Me'),
          ),
        ),
      ),
    );

    expect(find.text('Press Me'), findsOneWidget);

    await tester.tap(find.text('Press Me'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('TactilePressable handles pointer down and up with animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TactilePressable(
            child: Text('Elastic Button'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Elastic Button')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Elastic Button'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Elastic Button'), findsOneWidget);
  });
}

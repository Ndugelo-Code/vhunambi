// T7.3 — DnaStrengthMeter widget tests (REQ-DNA-HOME-01, REQ-DNA-NFR-01)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/dna_strength_meter.dart';

void main() {
  group('DnaStrengthMeter', () {
    testWidgets('renders without timer leaks when animated: false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DnaStrengthMeter(
              strengthPercent: 50,
              animated: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('dna_strength_meter')), findsOneWidget);
    });

    testWidgets('strengthPercent: 0 renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DnaStrengthMeter(
              strengthPercent: 0,
              animated: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('dna_strength_meter')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strengthPercent: 55 mid zone renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DnaStrengthMeter(
              strengthPercent: 55,
              animated: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('dna_strength_meter')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strengthPercent: 85 high zone renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DnaStrengthMeter(
              strengthPercent: 85,
              animated: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('dna_strength_meter')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not produce timer errors when animated: false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DnaStrengthMeter(
              strengthPercent: 75,
              animated: false,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

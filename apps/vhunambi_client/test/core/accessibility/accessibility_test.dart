import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/accessibility/a11y_button.dart';
import 'package:vhunambi_client/core/accessibility/a11y_focus_indicator.dart';
import 'package:vhunambi_client/core/accessibility/contrast_checker.dart';
import 'package:vhunambi_client/core/accessibility/keyboard_navigation_controller.dart';
import 'package:vhunambi_client/core/accessibility/semantic_label_builder.dart';

void main() {
  group('Accessibility Layer', () {
    testWidgets('A11yButton enforces minimum 48x48 touch bounding box', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: A11yButton(
                semanticLabel: 'Action Button',
                onPressed: () => tapped = true,
                child: const Text('Tap'),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(A11yButton);
      expect(buttonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(buttonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });

    testWidgets('A11yFocusIndicator renders border when hasFocus is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: A11yFocusIndicator(
              hasFocus: true,
              child: Text('Focused Content'),
            ),
          ),
        ),
      );

      final indicatorFinder = find.byType(A11yFocusIndicator);
      expect(indicatorFinder, findsOneWidget);
    });

    test('KeyboardNavigationController cycles through registered focus nodes', () {
      final controller = KeyboardNavigationController();
      final node1 = FocusNode();
      final node2 = FocusNode();
      final node3 = FocusNode();

      controller.registerAll([node1, node2, node3]);
      expect(controller.focusNodes.length, 3);
      expect(controller.orderOf(node1), equals(1));
      expect(controller.orderOf(node2), equals(2));
      expect(controller.orderOf(node3), equals(3));
      expect(controller.focusOrderSummary.length, equals(3));

      expect(controller.focusNext(), isTrue);
      expect(controller.currentIndex, 0);

      expect(controller.focusNext(), isTrue);
      expect(controller.currentIndex, 1);

      expect(controller.focusPrevious(), isTrue);
      expect(controller.currentIndex, 0);

      controller.dispose();
      node1.dispose();
      node2.dispose();
      node3.dispose();
    });

    test('SemanticLabelBuilder formats informative accessibility strings', () {
      expect(
        SemanticLabelBuilder.followButtonLabel('Fifi', false),
        'Follow Fifi',
      );
      expect(
        SemanticLabelBuilder.followButtonLabel('Fifi', true),
        'Unfollow Fifi',
      );
      expect(
        SemanticLabelBuilder.statTileLabel('120', 'Songs'),
        '120 Songs',
      );
      expect(
        SemanticLabelBuilder.tipButtonLabel('Fifi'),
        'Tip Fifi with credits',
      );
    });

    test('ContrastChecker calculates WCAG contrast ratios and levels correctly', () {
      // Black on White = 21.0 (AAA)
      final bwRatio = ContrastChecker.calculateContrastRatio(Colors.black, Colors.white);
      expect(bwRatio, closeTo(21.0, 0.5));
      expect(ContrastChecker.getWCAGLevel(bwRatio), WCAGLevel.aaa);

      // Low contrast = Fail
      final lowRatio = ContrastChecker.calculateContrastRatio(
        const Color(0xFF777777),
        const Color(0xFF888888),
      );
      expect(ContrastChecker.getWCAGLevel(lowRatio), WCAGLevel.fail);
    });
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/accessibility/a11y_audit_mode.dart';
import 'package:vhunambi_client/core/constants/feature_flags.dart';

void main() {
  group('A11yAuditMode & Developer Tools', () {
    setUp(() {
      FeatureFlags.reset();
    });

    test('A11yViolation serializes to JSON correctly', () {
      const violation = A11yViolation(
        type: A11yViolationType.touchTarget,
        elementDescription: 'Follow Button',
        severity: 'violation',
        details: {'width': 36, 'height': 36},
      );

      final json = violation.toJson();
      expect(json['type'], 'touchTarget');
      expect(json['label'], 'Touch Target (<48dp)');
      expect(json['element'], 'Follow Button');
      expect(json['severity'], 'violation');
      expect(json['details']['width'], 36);
    });

    test('A11yAuditReport calculates compliance percentages and exports JSON', () {
      final report = A11yAuditReport(
        violations: [
          const A11yViolation(
            type: A11yViolationType.touchTarget,
            elementDescription: 'Small Icon',
          ),
          const A11yViolation(
            type: A11yViolationType.contrast,
            elementDescription: 'Subtle Text',
          ),
        ],
        touchTargetCompliance: 90.0,
        contrastCompliance: 90.0,
      );

      expect(report.totalViolations, 2);
      expect(report.touchTargetCompliance, 90.0);
      expect(report.contrastCompliance, 90.0);

      final exported = report.exportJson();
      expect(exported, isNotEmpty);

      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['totalViolations'], 2);
      expect(decoded['touchTargetCompliancePercent'], 90.0);
      expect((decoded['violations'] as List).length, 2);
    });

    test('A11yAuditController tracks announcements, violations, and toggles flags', () {
      final controller = A11yAuditController(initialEnabled: false);
      expect(controller.isEnabled, isFalse);

      controller.toggle();
      expect(controller.isEnabled, isTrue);
      expect(FeatureFlags.enableA11yAuditMode, isTrue);

      controller.announce('Screen reader announces: Welcome');
      controller.announce('Screen reader announces: Followed Fifi');
      expect(controller.screenReaderAnnouncements.length, 2);
      expect(controller.screenReaderAnnouncements.first, 'Screen reader announces: Followed Fifi');

      controller.recordViolation(
        const A11yViolation(
          type: A11yViolationType.missingSemantics,
          elementDescription: 'Avatar Image',
        ),
      );
      expect(controller.recordedViolations.length, 1);

      final report = controller.generateReport();
      expect(report.totalViolations, 1);

      controller.clear();
      expect(controller.recordedViolations.isEmpty, isTrue);
      expect(controller.screenReaderAnnouncements.isEmpty, isTrue);
    });

    test('TouchTargetComplianceBadge color classifications', () {
      expect(TouchTargetComplianceBadge.complianceColor(48, 48), Colors.green);
      expect(TouchTargetComplianceBadge.complianceColor(52, 48), Colors.green);
      expect(TouchTargetComplianceBadge.complianceColor(44, 44), Colors.amber);
      expect(TouchTargetComplianceBadge.complianceColor(40, 47), Colors.amber);
      expect(TouchTargetComplianceBadge.complianceColor(36, 48), Colors.red);
      expect(TouchTargetComplianceBadge.complianceColor(32, 32), Colors.red);
    });

    testWidgets('SemanticCheckWrapper flags missing semantics', (tester) async {
      final controller = A11yAuditController(initialEnabled: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticCheckWrapper(
              elementName: 'Unlabeled IconButton',
              semanticLabel: null,
              controller: controller,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      expect(controller.recordedViolations.length, 1);
      expect(controller.recordedViolations.first.type, A11yViolationType.missingSemantics);
    });

    testWidgets('A11yAuditMode renders floating badge and drawer when enabled', (tester) async {
      final controller = A11yAuditController(initialEnabled: true);
      controller.announce('Active Screen: Artist Profile');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: A11yAuditMode(
                controller: controller,
                child: const SizedBox.expand(
                  child: Text('Artist Screen Content'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Artist Screen Content'), findsOneWidget);
      expect(find.textContaining('A11y Audit'), findsOneWidget);

      // Tap on audit floating badge to open panel
      await tester.tap(find.textContaining('A11y Audit'));
      await tester.pumpAndSettle();

      expect(find.text('Screen Reader & Audit Panel'), findsOneWidget);
      expect(find.text('Active Screen: Artist Profile'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
    });
  });
}

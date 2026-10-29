import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/contrast_utils.dart';

void main() {
  group('ContrastUtils', () {
    test('calculates maximum contrast for black on white', () {
      final ratio = ContrastUtils.calculateContrastRatio(
        Colors.black,
        Colors.white,
      );
      expect(ratio, closeTo(21.0, 0.01));
    });

    test('calculates minimum contrast for identical colors', () {
      final ratio = ContrastUtils.calculateContrastRatio(
        Colors.black,
        Colors.black,
      );
      expect(ratio, closeTo(1.0, 0.01));
    });

    test('is symmetric (order independent)', () {
      final r1 = ContrastUtils.calculateContrastRatio(Colors.black, Colors.white);
      final r2 = ContrastUtils.calculateContrastRatio(Colors.white, Colors.black);
      expect(r1, closeTo(r2, 0.001));
    });

    test('calculates WCAG AA compliant ratio for black on brand orange', () {
      final ratio = ContrastUtils.calculateContrastRatio(
        const Color(0xFF000000),
        const Color(0xFFF97316),
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('calculates failing ratio for gray on light gray', () {
      final ratio = ContrastUtils.calculateContrastRatio(
        const Color(0xFF777777),
        const Color(0xFF888888),
      );
      expect(ratio, lessThan(4.5));
    });
  });
}
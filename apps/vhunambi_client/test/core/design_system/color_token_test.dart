import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/color_token.dart';

void main() {
  group('ColorToken', () {
    test('creates token with all required fields', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFF000000),
      );
      expect(token.accent, const Color(0xFFF97316));
      expect(token.surfaceTint, const Color(0xFF0E3842));
      expect(token.glow, const Color(0x1AF97316));
      expect(token.textColor, const Color(0xFF000000));
    });

    test('auto factory calculates light text for dark accent', () {
      final token = ColorToken.auto(
        accent: const Color(0xFFF97316), // Orange, low luminance
        surfaceTint: const Color(0xFF0E3842),
        glow: const Color(0x1AF97316),
      );
      expect(token.textColor, const Color(0xFFFFFFFF));
    });

    test('auto factory calculates dark text for light accent', () {
      final token = ColorToken.auto(
        accent: const Color(0xFFFFFFFF), // White, high luminance
        surfaceTint: const Color(0xFF0E3842),
        glow: const Color(0x1AF97316),
      );
      expect(token.textColor, const Color(0xFF000000));
    });

    test('equality is based on all fields', () {
      const t1 = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFF000000),
      );
      const t2 = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFF000000),
      );
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('inequality detects field differences', () {
      const t1 = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFF000000),
      );
      const t2 = ColorToken(
        accent: Color(0xFF8B5CF6),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFF000000),
      );
      expect(t1, isNot(equals(t2)));
    });
  });
}
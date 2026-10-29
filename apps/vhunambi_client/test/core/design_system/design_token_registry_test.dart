import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/color_token.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_token_registry.dart';
import 'package:vhunambi_client/core/design_system/tokens/token_exceptions.dart';

void main() {
  group('DesignTokenRegistry', () {
    setUp(() {
      DesignTokenRegistry.reset();
    });

    tearDown(() {
      DesignTokenRegistry.reset();
    });

    test('starts empty and unsealed', () {
      expect(DesignTokenRegistry.genreCount, equals(0));
      expect(DesignTokenRegistry.moodCount, equals(0));
      expect(DesignTokenRegistry.isSealed, isFalse);
    });

    test('registers and retrieves genre token', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerGenre(Genre.amapiano, token);

      expect(DesignTokenRegistry.genreCount, equals(1));
      expect(DesignTokenRegistry.getGenreToken(Genre.amapiano), equals(token));
      expect(DesignTokenRegistry.getGenreAccent(Genre.amapiano),
          equals(const Color(0xFFF97316)));
      expect(DesignTokenRegistry.getGenreSurfaceTint(Genre.amapiano),
          equals(const Color(0xFF0E3842)));
      expect(DesignTokenRegistry.getGenreGlow(Genre.amapiano),
          equals(const Color(0x1AF97316)));
      expect(DesignTokenRegistry.getGenreTextColor(Genre.amapiano),
          equals(const Color(0xFFFFFFFF)));
    });

    test('registers and retrieves mood token', () {
      const token = ColorToken(
        accent: Color(0xFF8B5CF6),
        surfaceTint: Color(0xFF1E1B4B),
        glow: Color(0x1A8B5CF6),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerMood(Mood.energetic, token);

      expect(DesignTokenRegistry.moodCount, equals(1));
      expect(DesignTokenRegistry.getMoodToken(Mood.energetic), equals(token));
      expect(DesignTokenRegistry.getMoodAccent(Mood.energetic),
          equals(const Color(0xFF8B5CF6)));
    });

    test('throws DuplicateTokenException for duplicate genre', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerGenre(Genre.amapiano, token);

      expect(
        () => DesignTokenRegistry.registerGenre(Genre.amapiano, token),
        throwsA(isA<DuplicateTokenException>()),
      );
    });

    test('throws DuplicateTokenException for duplicate mood', () {
      const token = ColorToken(
        accent: Color(0xFF8B5CF6),
        surfaceTint: Color(0xFF1E1B4B),
        glow: Color(0x1A8B5CF6),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerMood(Mood.joyful, token);

      expect(
        () => DesignTokenRegistry.registerMood(Mood.joyful, token),
        throwsA(isA<DuplicateTokenException>()),
      );
    });

    test('throws TokenNotFoundException for unregistered genre', () {
      expect(
        () => DesignTokenRegistry.getGenreToken(Genre.amapiano),
        throwsA(isA<TokenNotFoundException>()),
      );
    });

    test('throws TokenNotFoundException for unregistered mood', () {
      expect(
        () => DesignTokenRegistry.getMoodToken(Mood.joyful),
        throwsA(isA<TokenNotFoundException>()),
      );
    });

    test('prevents registration after seal', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerGenre(Genre.amapiano, token);
      DesignTokenRegistry.seal();

      expect(DesignTokenRegistry.isSealed, isTrue);
      expect(
        () => DesignTokenRegistry.registerGenre(Genre.gqom, token),
        throwsA(isA<StateError>()),
      );
    });

    test('reset clears all tokens and unseals', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerGenre(Genre.amapiano, token);
      DesignTokenRegistry.seal();

      DesignTokenRegistry.reset();

      expect(DesignTokenRegistry.genreCount, equals(0));
      expect(DesignTokenRegistry.isSealed, isFalse);
      expect(
        () => DesignTokenRegistry.getGenreToken(Genre.amapiano),
        throwsA(isA<TokenNotFoundException>()),
      );
    });

    test('generateValidationReport returns contrast ratios', () {
      const token = ColorToken(
        accent: Color(0xFFF97316),
        surfaceTint: Color(0xFF0E3842),
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      );
      DesignTokenRegistry.registerGenre(Genre.amapiano, token);

      final report = DesignTokenRegistry.generateValidationReport();
      expect(report.containsKey('Genre: Amapiano'), isTrue);
      expect(report['Genre: Amapiano'], greaterThanOrEqualTo(4.5));
    });

    test('validateToken enforces minimum 4.5:1 contrast', () {
      final lowContrastToken = ColorToken(
        accent: const Color(0xFFF97316),
        surfaceTint: const Color(0xFF888888),
        glow: const Color(0x1AF97316),
        textColor: const Color(0xFF777777),
      );

      expect(
        () => DesignTokenRegistry.registerGenre(Genre.amapiano, lowContrastToken),
        throwsA(isA<ContrastViolationException>()),
      );
    });
  });
}
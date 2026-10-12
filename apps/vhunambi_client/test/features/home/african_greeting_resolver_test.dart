import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/home/presentation/utils/african_greeting_resolver.dart';

void main() {
  group('AfricanGreetingResolver Unit Tests', () {
    test('resolves pure Tshivenḓa greetings without English translations', () {
      final morning = DateTime(2026, 10, 12, 8, 30);
      final afternoon = DateTime(2026, 10, 12, 14, 0);
      final evening = DateTime(2026, 10, 12, 19, 45);

      expect(
        AfricanGreetingResolver.getGreeting(language: 'Tshivenḓa', now: morning),
        equals('Ndi matsheloni'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'Tshivenḓa', now: afternoon),
        equals('Masiari'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'Tshivenḓa', now: evening),
        equals('Madekwana'),
      );

      // Verify ZERO English translation brackets or parentheses
      final greeting =
          AfricanGreetingResolver.getGreeting(language: 'Tshivenḓa', now: afternoon);
      expect(greeting.contains('('), isFalse);
      expect(greeting.contains(')'), isFalse);
      expect(greeting.contains('Good'), isFalse);
    });

    test('resolves authentic isiZulu and isiXhosa greetings', () {
      final afternoon = DateTime(2026, 10, 12, 13, 0);

      expect(
        AfricanGreetingResolver.getGreeting(language: 'isiZulu', now: afternoon),
        equals('Sawubona emini'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'isiXhosa', now: afternoon),
        equals('Molo emini'),
      );
    });

    test('resolves Sepedi, Kiswahili, and Afrikaans greetings', () {
      final morning = DateTime(2026, 10, 12, 7, 0);
      final afternoon = DateTime(2026, 10, 12, 15, 0);
      final evening = DateTime(2026, 10, 12, 21, 0);

      expect(
        AfricanGreetingResolver.getGreeting(language: 'Sepedi', now: morning),
        equals('Thobela mosong'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'Kiswahili', now: afternoon),
        equals('Habari za mchana'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'Afrikaans', now: evening),
        equals('Goeienaand'),
      );
    });

    test('resolves English greetings only when English is explicitly chosen', () {
      final morning = DateTime(2026, 10, 12, 9, 0);
      final afternoon = DateTime(2026, 10, 12, 14, 0);
      final evening = DateTime(2026, 10, 12, 20, 0);

      expect(
        AfricanGreetingResolver.getGreeting(language: 'English', now: morning),
        equals('Good morning'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'English', now: afternoon),
        equals('Good afternoon'),
      );
      expect(
        AfricanGreetingResolver.getGreeting(language: 'English', now: evening),
        equals('Good evening'),
      );
    });

    test('returns accurate celestial time glyphs', () {
      expect(
        AfricanGreetingResolver.getTimeGlyph(now: DateTime(2026, 10, 12, 8)),
        equals('✨'),
      );
      expect(
        AfricanGreetingResolver.getTimeGlyph(now: DateTime(2026, 10, 12, 14)),
        equals('☀️'),
      );
      expect(
        AfricanGreetingResolver.getTimeGlyph(now: DateTime(2026, 10, 12, 22)),
        equals('🌙'),
      );
    });
  });
}

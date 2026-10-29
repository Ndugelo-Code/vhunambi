import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';

void main() {
  group('Genre enum', () {
    test('has exactly 8 values', () {
      expect(Genre.values.length, equals(8));
    });

    test('contains all expected genres', () {
      expect(Genre.values, containsAll([
        Genre.amapiano,
        Genre.afroHouse,
        Genre.gqom,
        Genre.kwaito,
        Genre.afroPop,
        Genre.maskandi,
        Genre.hipHop,
        Genre.gospel,
      ]));
    });

    test('displayName returns human-readable names', () {
      expect(Genre.amapiano.displayName, equals('Amapiano'));
      expect(Genre.afroHouse.displayName, equals('Afro House'));
      expect(Genre.gqom.displayName, equals('Gqom'));
      expect(Genre.kwaito.displayName, equals('Kwaito'));
      expect(Genre.afroPop.displayName, equals('Afro Pop'));
      expect(Genre.maskandi.displayName, equals('Maskandi'));
      expect(Genre.hipHop.displayName, equals('Hip-Hop'));
      expect(Genre.gospel.displayName, equals('Gospel'));
    });
  });

  group('Mood enum', () {
    test('has exactly 5 values', () {
      expect(Mood.values.length, equals(5));
    });

    test('contains all expected moods', () {
      expect(Mood.values, containsAll([
        Mood.joyful,
        Mood.melancholic,
        Mood.energetic,
        Mood.calm,
        Mood.romantic,
      ]));
    });

    test('displayName returns human-readable names', () {
      expect(Mood.joyful.displayName, equals('Joyful'));
      expect(Mood.melancholic.displayName, equals('Melancholic'));
      expect(Mood.energetic.displayName, equals('Energetic'));
      expect(Mood.calm.displayName, equals('Calm'));
      expect(Mood.romantic.displayName, equals('Romantic'));
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/home/domain/models/african_rhythm_matrix.dart';

void main() {
  group('AfricanRhythmMatrix (Task 31.1 & 31.2)', () {
    test('schedules 7 distinct regional African genres for weekdays 1..7', () {
      expect(AfricanRhythmMatrix.schedule.length, equals(7));

      final weekdays = AfricanRhythmMatrix.schedule
          .map((s) => s.weekday)
          .toSet();
      expect(weekdays, equals({1, 2, 3, 4, 5, 6, 7}));

      final monday = AfricanRhythmMatrix.forWeekday(1);
      expect(monday.genre, equals('Amapiano'));
      expect(monday.bpm, equals(113));
      expect(monday.musicalKey, equals('F# Minor'));

      final tuesday = AfricanRhythmMatrix.forWeekday(2);
      expect(tuesday.genre, equals('Gqom'));
      expect(tuesday.bpm, equals(127));

      final wednesday = AfricanRhythmMatrix.forWeekday(3);
      expect(wednesday.genre, equals('Afro-Indigenous'));
      expect(wednesday.title, contains('Tshivenḓa'));

      final thursday = AfricanRhythmMatrix.forWeekday(4);
      expect(thursday.genre, equals('Maskandi'));
      expect(thursday.musicalKey, equals('D Major'));

      final friday = AfricanRhythmMatrix.forWeekday(5);
      expect(friday.genre, equals('Kwaito'));
      expect(friday.bpm, equals(110));

      final saturday = AfricanRhythmMatrix.forWeekday(6);
      expect(saturday.genre, equals('Afro-Tech'));
      expect(saturday.bpm, equals(124));

      final sunday = AfricanRhythmMatrix.forWeekday(7);
      expect(sunday.genre, equals('Gospel'));
      expect(sunday.bpm, equals(78));
    });

    test('clamps out-of-range weekday inputs cleanly to Monday (1)', () {
      expect(AfricanRhythmMatrix.forWeekday(0).weekday, equals(1));
      expect(AfricanRhythmMatrix.forWeekday(8).weekday, equals(1));
      expect(AfricanRhythmMatrix.forWeekday(-5).weekday, equals(1));
    });

    test('value equality and hashCode are consistent', () {
      final a = AfricanRhythmMatrix.forWeekday(4);
      final b = AfricanRhythmMatrix.forWeekday(4);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}

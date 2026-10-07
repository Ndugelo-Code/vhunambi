import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/notifications/presentation/utils/time_ago_utils.dart';

void main() {
  group('TimeAgoUtils', () {
    final fixedClock = DateTime(2026, 9, 26, 12, 0, 0);

    test('returns "Just now" for times under 45 seconds ago', () {
      final justNow = fixedClock.subtract(const Duration(seconds: 30));
      expect(TimeAgoUtils.format(justNow, clock: fixedClock), 'Just now');
    });

    test('returns "Just now" for future timestamps', () {
      final future = fixedClock.add(const Duration(seconds: 10));
      expect(TimeAgoUtils.format(future, clock: fixedClock), 'Just now');
    });

    test('formats singular minute correctly', () {
      final oneMinuteAgo = fixedClock.subtract(const Duration(minutes: 1));
      expect(
        TimeAgoUtils.format(oneMinuteAgo, clock: fixedClock),
        '1 minute ago',
      );
    });

    test('formats plural minutes correctly', () {
      final nineMinutesAgo = fixedClock.subtract(const Duration(minutes: 9));
      expect(
        TimeAgoUtils.format(nineMinutesAgo, clock: fixedClock),
        '9 minutes ago',
      );
    });

    test('formats singular hour correctly', () {
      final oneHourAgo = fixedClock.subtract(const Duration(hours: 1));
      expect(
        TimeAgoUtils.format(oneHourAgo, clock: fixedClock),
        '1 hour ago',
      );
    });

    test('formats plural hours correctly', () {
      final threeHoursAgo = fixedClock.subtract(const Duration(hours: 3));
      expect(
        TimeAgoUtils.format(threeHoursAgo, clock: fixedClock),
        '3 hours ago',
      );
    });

    test('formats singular day correctly', () {
      final oneDayAgo = fixedClock.subtract(const Duration(days: 1));
      expect(
        TimeAgoUtils.format(oneDayAgo, clock: fixedClock),
        '1 day ago',
      );
    });

    test('formats plural days correctly', () {
      final fourDaysAgo = fixedClock.subtract(const Duration(days: 4));
      expect(
        TimeAgoUtils.format(fourDaysAgo, clock: fixedClock),
        '4 days ago',
      );
    });

    test('formats calendar date for timestamps older than 7 days', () {
      final tenDaysAgo = DateTime(2026, 9, 16, 10, 0, 0);
      expect(
        TimeAgoUtils.format(tenDaysAgo, clock: fixedClock),
        '16/09/2026',
      );
    });
  });
}

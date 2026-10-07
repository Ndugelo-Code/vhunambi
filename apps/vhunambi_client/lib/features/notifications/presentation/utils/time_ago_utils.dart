class TimeAgoUtils {
  /// Converts a [DateTime] into a human-readable relative time string.
  ///
  /// An optional [clock] can be passed for deterministic testing.
  static String format(DateTime dateTime, {DateTime? clock}) {
    final now = clock ?? DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '$day/$month/$year';
    }
  }
}

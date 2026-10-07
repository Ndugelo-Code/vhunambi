/// Presentation-level formatters shared by the collection vault, detail view
/// and split sheet (Blueprint 13 §2.4).
const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `27 Sep 2026` — split sheet `Created:` and release metadata rendering.
String formatCollectionDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// `18 mins` / `1 hr 5 mins` — aggregate runtime of the resolved track list.
String formatCollectionDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  if (minutes < 60) return '$minutes mins';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours hr $remainingMinutes mins';
}

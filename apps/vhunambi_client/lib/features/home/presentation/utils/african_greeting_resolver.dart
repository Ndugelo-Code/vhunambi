import 'package:flutter/foundation.dart';

/// Cultural African Greeting Resolver (Vhunambi Indigenous Identity).
///
/// Resolves time-aware greetings in the creator's chosen home language
/// with ZERO English translations or subtitles (REQ-HOME-01).
@immutable
class AfricanGreetingResolver {
  const AfricanGreetingResolver._();

  /// Returns the authentic time greeting in [language].
  ///
  /// Time brackets:
  /// - Morning: 04:00 - 11:59
  /// - Afternoon: 12:00 - 16:59
  /// - Evening / Night: 17:00 - 03:59
  static String getGreeting({
    required String language,
    DateTime? now,
  }) {
    final dateTime = now ?? DateTime.now();
    final hour = dateTime.hour;

    final isMorning = hour >= 4 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;

    final normalized = _normalizeLanguage(language);

    switch (normalized) {
      case 'tshivenda':
        if (isMorning) return 'Ndi matsheloni';
        if (isAfternoon) return 'Masiari';
        return 'Madekwana';

      case 'isizulu':
        if (isMorning) return 'Sawubona ekuseni';
        if (isAfternoon) return 'Sawubona emini';
        return 'Sawubona kusihlwa';

      case 'isixhosa':
        if (isMorning) return 'Molo kusasa';
        if (isAfternoon) return 'Molo emini';
        return 'Molo ngokuhlwa';

      case 'sepedi':
      case 'sesothosalaboa':
        if (isMorning) return 'Thobela mosong';
        if (isAfternoon) return 'Thobela mosegare';
        return 'Thobela mantsiboa';

      case 'setswana':
        if (isMorning) return 'Dumela mo mosong';
        if (isAfternoon) return 'Dumela mo motshegareng';
        return 'Dumela maitsiboa';

      case 'sesotho':
        if (isMorning) return 'Dumela hoseng';
        if (isAfternoon) return 'Dumela motsheare';
        return 'Dumela mantsiboya';

      case 'xitsonga':
        if (isMorning) return 'Avuxeni';
        if (isAfternoon) return 'I nhlikanhi';
        return 'Riperile';

      case 'siswati':
        if (isMorning) return 'Sawubona ekuseni';
        if (isAfternoon) return 'Sawubona emini';
        return 'Sawubona ebusuku';

      case 'kiswahili':
      case 'swahili':
        if (isMorning) return 'Habari za asubuhi';
        if (isAfternoon) return 'Habari za mchana';
        return 'Habari za jioni';

      case 'yoruba':
        if (isMorning) return 'Ẹ kárọ̀';
        if (isAfternoon) return 'Ẹ káàsán';
        return 'Ẹ kúulẹ́';

      case 'shona':
        if (isMorning) return 'Mangwanani';
        if (isAfternoon) return 'Masikati';
        return 'Manheru';

      case 'afrikaans':
        if (isMorning) return 'Goeiemôre';
        if (isAfternoon) return 'Goeiemiddag';
        return 'Goeienaand';

      case 'english':
      default:
        if (isMorning) return 'Good morning';
        if (isAfternoon) return 'Good afternoon';
        return 'Good evening';
    }
  }

  /// Returns a subtle celestial glyph matching the time period.
  static String getTimeGlyph({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 4 && hour < 12) {
      return '✨'; // Morning fresh spark
    } else if (hour >= 12 && hour < 17) {
      return '☀️'; // Midday sun
    } else {
      return '🌙'; // Evening moon
    }
  }

  static String _normalizeLanguage(String lang) {
    return lang
        .toLowerCase()
        .replaceAll('ḓ', 'd')
        .replaceAll('ṱ', 't')
        .replaceAll('ḽ', 'l')
        .replaceAll('ṋ', 'n')
        .replaceAll(' ', '')
        .trim();
  }
}

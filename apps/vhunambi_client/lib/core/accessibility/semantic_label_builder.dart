/// Static helper generating accessible screen reader announcements and semantic labels.
abstract final class SemanticLabelBuilder {
  static String followButtonLabel(String artistName, bool isFollowing) {
    return isFollowing
        ? 'Unfollow $artistName'
        : 'Follow $artistName';
  }

  static String statTileLabel(String value, String statName) {
    return '$value $statName';
  }

  static String tipButtonLabel(String artistName) {
    return 'Tip $artistName with credits';
  }

  static String shareButtonLabel(String artistName) {
    return 'Share $artistName\'s profile';
  }

  static String releaseCardLabel(String title, String type, String date) {
    return '$title, $type release, published $date';
  }
}

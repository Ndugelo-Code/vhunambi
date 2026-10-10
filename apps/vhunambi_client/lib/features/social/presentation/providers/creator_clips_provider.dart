import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/published_clip.dart';
import 'social_feed_provider.dart';

/// Resolves every clip authored by a given `creatorId`, newest-first.
///
/// Backs the creator profile "Clips & Reels" grid (REQ-SOC-07 / REQ-SOC-23).
/// Reactive: it re-derives whenever the feed changes (a new publish or a like
/// toggle propagates to the creator's grid automatically).
final creatorClipsFamilyProvider =
    Provider.family<List<PublishedClip>, String>((ref, creatorId) {
  final feed = ref.watch(socialFeedProvider);
  return feed.clips.where((clip) => clip.creatorId == creatorId).toList();
});

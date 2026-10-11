import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/stem_remix_context.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';

/// Manages active reel remix context across Studio and Pocket DAW (REQ-RMX-02).
class StemRemixNotifier extends StateNotifier<StemRemixContext?> {
  final Ref _ref;

  StemRemixNotifier(this._ref) : super(null);

  /// Initiates remix workflow from a published reel.
  ///
  /// Extracts the source clip's metadata, stems, and DNA into [StemRemixContext]
  /// and synchronizes the active track title on [stemMixerProvider].
  void initiateRemix(PublishedClip clip) {
    final context = StemRemixContext(
      parentClipId: clip.id,
      parentCreatorUsername: clip.creatorUsername,
      parentCreatorDisplayName: clip.creatorDisplayName,
      parentTrackTitle: clip.title,
      parentCoverArtUrl: clip.coverUrl,
      originalDna: clip.dna,
    );

    state = context;

    // Load into the pocket stem mixer
    _ref.read(stemMixerProvider.notifier).resetMix();
  }

  /// Clears active remix context when returning to single-track workflow.
  void clearRemix() {
    state = null;
  }
}

/// Global provider tracking current active reel remix session.
final stemRemixProvider =
    StateNotifierProvider<StemRemixNotifier, StemRemixContext?>((ref) {
  return StemRemixNotifier(ref);
});

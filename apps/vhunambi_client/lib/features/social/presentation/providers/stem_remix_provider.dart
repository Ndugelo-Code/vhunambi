import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/stem_remix_context.dart';

/// Manages active reel remix context across Studio and Pocket DAW (REQ-RMX-02, Phase 37).
class StemRemixNotifier extends StateNotifier<StemRemixContext?> {
  final Ref _ref;

  StemRemixNotifier(this._ref) : super(null);

  /// Initiates remix workflow from a published reel.
  ///
  /// Extracts the source clip's metadata, stems, and DNA into [StemRemixContext]
  /// and synchronizes the active track title on [stemMixerProvider].
  void initiateRemix(
    PublishedClip clip, {
    RemixCreationMode mode = RemixCreationMode.aiStudioRemix,
  }) {
    final context = StemRemixContext(
      parentClipId: clip.id,
      parentCreatorUsername: clip.creatorUsername,
      parentCreatorDisplayName: clip.creatorDisplayName,
      parentTrackTitle: clip.title,
      parentCoverArtUrl: clip.coverUrl,
      parentCreatorId: clip.creatorId,
      creationMode: mode,
      remixGenerationDepth: clip.remixGenerationDepth + 1,
      coCreationSplits: [
        const SplitParticipant(
          name: 'Me (Remixer)',
          role: 'Remixer',
          sharePercent: 70.0,
        ),
        SplitParticipant(
          name: clip.creatorDisplayName,
          role: 'Original Producer',
          sharePercent: 30.0,
          creatorId: clip.creatorId,
          handle: '@${clip.creatorUsername}',
        ),
      ],
      originalDna: clip.dna,
    );

    state = context;

    // Load into the pocket stem mixer
    _ref.read(stemMixerProvider.notifier).resetMix();
  }

  /// Sets an explicit context directly.
  void setContext(StemRemixContext context) {
    state = context;
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

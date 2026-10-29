import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/just_audio_multi_stem_engine.dart';
import '../../domain/models/stem_mixer_state.dart';
import '../../domain/services/i_multi_stem_audio_engine.dart';
import 'audio_bridge_providers.dart';
import 'stem_mixer_provider.dart';

/// Production multi-stem audio engine provider (REQ-STEM-AUDIO-01 .. 06).
///
/// Defaults to [JustAudioMultiStemEngine] in production.
/// Tests can override with [HeadlessMultiStemEngine] to prevent timer leaks.
///
/// NOTE (TRAP-24-11): One-way dependency: Engine listens to stemMixerProvider.
/// The mixer state NEVER listens to the engine, preventing provider dependency cycles.
final multiStemAudioEngineProvider = Provider<IMultiStemAudioEngine>((ref) {
  final sessionManager = ref.watch(audioSessionManagerProvider);
  final engine = JustAudioMultiStemEngine(sessionManager: sessionManager);
  ref.onDispose(() => engine.dispose());

  // One-way sync: mixer state -> engine volume/mute/solo
  ref.listen<StemMixerState>(
    stemMixerProvider,
    (_, next) => engine.applyMixerState(next),
    fireImmediately: true,
  );

  return engine;
});

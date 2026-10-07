import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline/presentation/providers/offline_providers.dart';
import '../../data/services/audio_session_manager.dart';
import '../../data/services/audio_source_resolver.dart';
import '../../data/services/vhunambi_audio_handler.dart';

/// Hybrid vault/cloud audio source resolver (T9.2, REQ-AUD-09).
///
/// Reads the offline cache through Phase 8's `offlineStorageServiceProvider` and
/// always consults the live `isOfflineModeForced` preference through a callback,
/// so the resolver never has to be rebuilt when the preference toggles.
final audioSourceResolverProvider = Provider<IAudioSourceResolver>((ref) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);

  return AudioSourceResolver(
    offlineStorage: offlineStorage,
    offlineModeGuard: () =>
        ref.read(offlinePreferencesProvider).isOfflineModeForced,
  );
});

/// Hardware audio session / focus manager (T9.3, REQ-AUD-06 → REQ-AUD-08).
final audioSessionManagerProvider = Provider<IAudioSessionManager>((ref) {
  final manager = AudioSessionManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Active OS media transport handler (T9.4, REQ-AUD-01 → REQ-AUD-05).
///
/// Returns the headless [TestVhunambiAudioHandler] so `flutter test`, headless CI
/// and unsupported desktops never touch a platform channel (REQ-AUD-02).
///
/// The hybrid resolver is injected through [DeferredAudioSourceResolver] so that
/// merely creating the handler never opens Phase 8's Hive vault.
///
/// Production builds register the real platform service at boot via
/// [bootstrapPlatformAudioHandler] and override this provider with the returned
/// `just_audio` backed handler inside the root `ProviderScope`.
final audioHandlerProvider = Provider<IVhunambiAudioHandler>((ref) {
  final handler = TestVhunambiAudioHandler(
    sourceResolver: DeferredAudioSourceResolver(
      () => ref.read(audioSourceResolverProvider),
    ),
    sessionManager: ref.watch(audioSessionManagerProvider),
  );
  ref.onDispose(handler.dispose);
  return handler;
});

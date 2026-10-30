import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/stem_remix_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/vocal_identity_provider.dart';

void main() {
  group('Phase D: Viral Remix in Studio & Lineage Propagation', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final testDna = SongMetadataDna(
      id: 'dna_makhado_remix',
      title: 'Makhado Sunrise',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      musical: const MusicalDna(
        bpm: 114,
        key: 'F#m',
        energyBracket: 'mid',
        durationSec: 180,
      ),
      vocals: const VocalsDna(
        deliveryMode: 'melodic',
        gender: 'female',
        energy: 'high',
      ),
      visualTheme: const VisualThemeDna(
        mood: 'Cinematic',
        comfyPrompt: 'amapiano sunrise studio',
        seed: 42,
      ),
    );

    final parentClip = PublishedClip(
      id: 'clip_parent_123',
      trackId: 'track_parent_123',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      title: 'Makhado Sunrise',
      genre: 'Amapiano',
      audioUrl: 'https://cdn.vhunambi.com/audio/makhado.mp3',
      coverUrl: 'https://cdn.vhunambi.com/cover/makhado.jpg',
      dna: testDna,
      publishedAt: DateTime.now(),
    );

    test(
      'StemRemixNotifier initiates remix context and sets attributionLineage',
      () {
        final notifier = container.read(stemRemixProvider.notifier);
        notifier.initiateRemix(parentClip);

        final remixContext = container.read(stemRemixProvider);
        expect(remixContext, isNotNull);
        expect(remixContext!.parentClipId, 'clip_parent_123');
        expect(remixContext.parentCreatorUsername, 'makhadzi');
        expect(
          remixContext.attributionLineage,
          '🔁 Remixed from @makhadzi\'s "Makhado Sunrise"',
        );
      },
    );

    test(
      'MelodySketchpadNotifier.initializeFromRemixDna locks key, BPM, and scale',
      () {
        final notifier = container.read(melodySketchpadProvider.notifier);
        notifier.initializeFromRemixDna(
          musicalKey: 'F#m',
          bpm: 114,
          genre: 'Amapiano',
        );

        final pattern = container.read(melodySketchpadProvider).activePattern;
        expect(pattern.musicalKey, 'F#m');
        expect(pattern.bpm, 114);
        expect(pattern.name, contains('Remix Stems'));
      },
    );

    test(
      'VocalIdentityNotifier.initializeFromRemixDna aligns delivery style',
      () {
        final notifier = container.read(vocalIdentityProvider.notifier);
        notifier.initializeFromRemixDna(
          deliveryMode: 'afroSoulMelodic',
          genre: 'Amapiano',
        );

        final activeArchetype = container
            .read(vocalIdentityProvider)
            .activeArchetype;
        expect(activeArchetype, isNotNull);
      },
    );

    test('StudioForm and Remix Workflow loads prompt and genre seamlessly', () {
      // 1. Initiate remix
      container.read(stemRemixProvider.notifier).initiateRemix(parentClip);
      final remix = container.read(stemRemixProvider)!;

      // 2. Set studio form
      final studio = container.read(studioFormProvider.notifier);
      studio.setGenre(parentClip.genre);
      studio.updatePrompt(
        'Remix inspired by ${parentClip.title} by @${parentClip.creatorUsername}',
      );

      final formState = container.read(studioFormProvider);
      expect(formState.genre, 'Amapiano');
      expect(formState.prompt, contains('Makhado Sunrise'));
      expect(formState.prompt, contains('@makhadzi'));

      // 3. Publish clip from ContentStudio carrying remix lineage
      final contentStudio = container.read(contentStudioProvider.notifier);
      contentStudio.initializeWithDna(
        dna: testDna,
        audioUrl: 'https://cdn.vhunambi.com/audio/remix.mp3',
        coverArtUrl: 'https://cdn.vhunambi.com/cover/remix.jpg',
      );

      final publishedRemix = contentStudio.publishClipToProfile(
        caption: 'My flip of this legendary tune!',
        tags: ['Amapiano', 'Remix'],
        remixedFromClipId: remix.parentClipId,
        remixAttribution: remix.attributionLineage,
      );

      expect(publishedRemix, isNotNull);
      expect(publishedRemix!.isRemix, isTrue);
      expect(publishedRemix.remixedFromClipId, 'clip_parent_123');
      expect(
        publishedRemix.remixAttribution,
        '🔁 Remixed from @makhadzi\'s "Makhado Sunrise"',
      );

      // 4. Clear remix after publish
      container.read(stemRemixProvider.notifier).clearRemix();
      expect(container.read(stemRemixProvider), isNull);
    });
  });
}

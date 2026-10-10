import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';

SongMetadataDna _sampleDna() => SongMetadataDna(
      id: 'dna_reel_test',
      title: 'Makhado Sun',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      musical: const MusicalDna(
        bpm: 114,
        key: 'Am',
        energyBracket: 'mid',
        durationSec: 210,
      ),
      vocals: const VocalsDna(
        deliveryMode: 'melodic',
        gender: 'female',
        energy: 'mid',
      ),
      visualTheme: const VisualThemeDna(
        mood: 'Cinematic',
        comfyPrompt: 'sunrise piano session',
        seed: 8,
        aspectRatio: '9:16',
      ),
    );

PublishedClip _sampleClip({
  String id = 'clip_test_1',
  String title = 'Makhado Sun',
  int likeCount = 100,
  bool isLiked = false,
}) =>
    PublishedClip(
      id: id,
      trackId: 'track_test_1',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      isCreatorVerified: true,
      title: title,
      caption: 'Late night sessions in Limpopo 🎹',
      tags: const ['Amapiano', 'Tshivenḓa'],
      genre: 'Amapiano',
      audioUrl: 'https://cdn/test.mp3',
      coverUrl: '',
      dna: _sampleDna(),
      likeCount: likeCount,
      isLikedByMe: isLiked,
      publishedAt: DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('KineticReelsModal renders clip metadata, sound pill, and action rail',
      (tester) async {
    final clip = _sampleClip();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: KineticReelsModal(clips: [clip]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@makhadzi'), findsOneWidget);
    expect(find.text('Late night sessions in Limpopo 🎹'), findsOneWidget);
    expect(find.text('Makhado Sun • Makhadzi'), findsOneWidget);
    expect(find.byKey(const Key('reel_like_btn')), findsOneWidget);
    expect(find.byKey(const Key('reel_share_btn')), findsOneWidget);
    expect(find.byKey(const Key('reel_sound_pill')), findsOneWidget);
  });

  testWidgets('Tapping like button toggles like state reactively', (tester) async {
    final clip = _sampleClip(likeCount: 50, isLiked: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialFeedProvider.overrideWith((ref) {
            final notifier = SocialFeedNotifier();
            notifier.prependClip(clip);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: KineticReelsModal(clips: [clip]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reel_like_btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reel_like_btn')));
    await tester.pumpAndSettle();

    // Like toggles optimistically
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('Tapping sound pill executes Remix in Studio loop', (tester) async {
    final clip = _sampleClip();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: KineticReelsModal(clips: [clip]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reel_sound_pill')));
    await tester.pump();

    expect(find.text('Loaded sound into Studio: Makhado Sun 🎵'), findsOneWidget);
  });
}

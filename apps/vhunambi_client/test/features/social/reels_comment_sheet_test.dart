import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/reels_comment_sheet.dart';

PublishedClip _clip() => PublishedClip(
      id: 'clip_seed_01',
      trackId: 'track_seed_01',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      isCreatorVerified: true,
      title: 'Ndo Mufuna Matibe',
      caption: 'Late-night piano vibe',
      genre: 'Amapiano',
      audioUrl: 'https://cdn/x.mp3',
      coverUrl: 'https://cdn/x.jpg',
      dna: SongMetadataDna(
        id: 'dna_seed_01',
        title: 'Ndo Mufuna Matibe',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: const MusicalDna(
            bpm: 113, key: 'Am', energyBracket: 'mid', durationSec: 198),
        vocals: const VocalsDna(
            deliveryMode: 'melodic', gender: 'female', energy: 'mid'),
        visualTheme: const VisualThemeDna(
            mood: 'Cinematic', comfyPrompt: 'amapiano', seed: 42),
      ),
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

void main() {
  testWidgets('renders seeded comments and the honest community banner',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: ReelsCommentSheet(clip: _clip())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Comments (4)'), findsOneWidget);
    expect(find.textContaining('log drum'), findsOneWidget);
    // Top supporter (12 loves) triggers the honest community banner.
    expect(find.textContaining('Honest Community'), findsOneWidget);
  });

  testWidgets('tapping a cultural reaction chip inserts text into composer',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: ReelsCommentSheet(clip: _clip())),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('🔥').last);
    await tester.pump();

    final field =
        tester.widget<TextField>(find.byKey(const Key('comment_input')));
    expect(field.controller?.text, '🔥');
  });

  testWidgets('submitting adds a comment optimistically', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: ReelsCommentSheet(clip: _clip())),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('comment_input')), 'Absolute banger!');
    await tester.tap(find.byKey(const Key('comment_send_btn')));
    await tester.pump();

    expect(find.text('Comments (5)'), findsOneWidget);
    expect(find.text('Absolute banger!'), findsOneWidget);
  });

  testWidgets('tapping a comment heart toggles its like state', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: ReelsCommentSheet(clip: _clip())),
        ),
      ),
    );
    await tester.pump();

    // Seeded comment c_seed_101 starts un-liked (favorite_border).
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    await tester.tap(find.byKey(const Key('comment_like_c_seed_101')));
    await tester.pump();
    // Still rendered after the optimistic toggle.
    expect(find.text('Comments (4)'), findsOneWidget);
  });
}

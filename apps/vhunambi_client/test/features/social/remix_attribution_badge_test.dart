import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/remix_attribution_badge.dart';

SongMetadataDna _dna() => SongMetadataDna(
      id: 'dna_badge',
      title: 'Remix',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      musical: const MusicalDna(
          bpm: 113, key: 'Am', energyBracket: 'mid', durationSec: 198),
      vocals: const VocalsDna(
          deliveryMode: 'melodic', gender: 'female', energy: 'mid'),
      visualTheme: const VisualThemeDna(
          mood: 'Cinematic', comfyPrompt: 'amapiano', seed: 42),
    );

PublishedClip _clip({bool isRemix = false}) => PublishedClip(
      id: 'clip_badge',
      trackId: 'track_badge',
      creatorId: 'creator_fifi',
      creatorUsername: 'fifi',
      creatorDisplayName: 'Fifi',
      title: 'Sunrise Remix',
      genre: 'Amapiano',
      audioUrl: 'https://cdn/x.mp3',
      coverUrl: '',
      dna: _dna(),
      remixedFromClipId: isRemix ? 'clip_parent_1' : null,
      remixAttribution: isRemix ? "🔁 Remixed from @makhadzi's \"Makhado Sunrise\"" : null,
      publishedAt: DateTime.now(),
    );

void main() {
  testWidgets('renders lineage attribution when the clip is a remix',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: Center(child: RemixAttributionBadge(clip: _clip(isRemix: true)))),
      ),
    );

    expect(find.byKey(const Key('remix_attribution_badge')), findsOneWidget);
    expect(find.textContaining('Remixed from @makhadzi'), findsOneWidget);
  });

  testWidgets('renders nothing for an original (non-remix) clip',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: Center(child: RemixAttributionBadge(clip: _clip(isRemix: false)))),
      ),
    );

    expect(find.byKey(const Key('remix_attribution_badge')), findsNothing);
  });

  testWidgets('tapping the badge executes the tap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: RemixAttributionBadge(
              clip: _clip(isRemix: true),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('remix_attribution_badge')));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

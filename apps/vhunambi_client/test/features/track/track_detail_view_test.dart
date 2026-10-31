import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/comments_section.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/emoji_reaction_deck.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/lyrics_teleprompter.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/more_like_this_shelf.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/prompt_attribution_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/stem_separation_lab.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_actions_bar.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_hero_section.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/utility_tool_dock.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/waveform_scrubber.dart';

Future<void> _pumpTrackDetail(
  WidgetTester tester, {
  String trackId = 'seed-01',
  Size size = const Size(1280, 2800),
  VoidCallback? onNavigateToStudio,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: TrackDetailView(
          trackId: trackId,
          onNavigateToStudio: onNavigateToStudio,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TrackDetailView renders all 11 core dissection components',
      (WidgetTester tester) async {
    await _pumpTrackDetail(tester);

    // 1. Hero Showcase (REQ-TRK-02, REQ-TRK-03)
    expect(find.byType(TrackHeroSection), findsOneWidget);
    expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
    expect(find.textContaining('Amapiano • Tshivenḓa • 3:18'), findsOneWidget);
    expect(find.text('🛡️ Personal Use'), findsOneWidget);
    expect(find.textContaining('100% royalty-free'), findsOneWidget);
    expect(find.text('Fifi'), findsOneWidget);

    // 2. Social Action Bar (REQ-TRK-04)
    expect(find.byType(TrackActionsBar), findsOneWidget);
    expect(find.text('Remix'), findsOneWidget);
    expect(find.text('Tip'), findsOneWidget);

    // 3. Utility Dock (REQ-TRK-05)
    expect(find.byType(UtilityToolDock), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);

    // 4. Cultural Emoji Reactions (REQ-TRK-06)
    expect(find.byType(EmojiReactionDeck), findsOneWidget);
    expect(find.byKey(const Key('reaction_fire')), findsOneWidget);
    expect(find.byKey(const Key('reaction_love')), findsOneWidget);

    // 5. Amplitude Waveform Scrubber (REQ-TRK-07)
    expect(find.byType(WaveformScrubber), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WaveformScrubber),
        matching: find.byIcon(Icons.play_circle_fill_rounded),
      ),
      findsOneWidget,
    );

    // 6. Lyrics Teleprompter (REQ-TRK-08)
    expect(find.byType(LyricsTeleprompter), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.textContaining('Moonlight falls on your shoulder'), findsOneWidget);

    // 7. Stem Separation Lab (REQ-TRK-09)
    expect(find.byType(StemSeparationLab), findsOneWidget);
    expect(find.text('Stem Separation Lab'), findsOneWidget);
    expect(find.text('Separate'), findsOneWidget);

    // 8. Prompt Attribution Card (REQ-TRK-10)
    expect(find.byType(PromptAttributionCard), findsOneWidget);
    expect(find.text('PROMPT'), findsOneWidget);
    expect(find.text('Remix Prompt ✨'), findsOneWidget);

    // 9. Comments Discussion Section (REQ-TRK-11)
    expect(find.byType(CommentsSection), findsOneWidget);
    expect(find.textContaining('Comments (2)'), findsOneWidget);
    expect(find.text('Sipho Beats'), findsOneWidget);

    // 10. More Like This Shelf (REQ-TRK-11)
    expect(find.byType(MoreLikeThisShelf), findsOneWidget);
    expect(find.text('More Like This'), findsOneWidget);
  });

  testWidgets('TrackDetailView toggles like and updates like count',
      (WidgetTester tester) async {
    await _pumpTrackDetail(tester);

    // Initial like count for seed-01 is 1 in TrackActionsBar
    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // Tap Like within TrackActionsBar
    final likeButton = find.descendant(
      of: find.byType(TrackActionsBar),
      matching: find.byType(InkWell),
    ).first;
    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    // Tally decremented to 0 in TrackActionsBar
    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    // Tap Like again to re-like
    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    // Tally back to 1 in TrackActionsBar
    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TrackDetailView adds a new comment to discussion thread',
      (WidgetTester tester) async {
    await _pumpTrackDetail(tester);

    final commentField = find.byType(TextField);
    expect(commentField, findsOneWidget);

    await tester.enterText(commentField, 'Mindblowing sound design!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mindblowing sound design!'), findsOneWidget);
  });

  testWidgets('TrackDetailView stem separation triggers simulation and extracts 4 stems',
      (WidgetTester tester) async {
    await _pumpTrackDetail(tester);

    final extractButton = find.text('Separate');
    expect(extractButton, findsOneWidget);

    await tester.tap(extractButton);
    // Pump through the 40ms delayed transitions in separateStems
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    // Check that all 4 isolated stems are displayed
    expect(find.text('Vocals'), findsOneWidget);
    expect(find.text('Drums'), findsOneWidget);
    expect(find.text('Bass & Log Drums'), findsOneWidget);
    expect(find.text('Instrumental'), findsOneWidget);
  });
}

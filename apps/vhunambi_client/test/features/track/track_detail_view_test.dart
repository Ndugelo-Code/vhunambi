import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/threaded_comments_section.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/emoji_reaction_deck.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/lyrics_teleprompter.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/more_like_this_shelf.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/prompt_attribution_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/stem_separation_lab.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_actions_bar.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_hero_section.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_sonic_telemetry_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/utility_tool_dock.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/waveform_scrubber.dart';

Future<void> _pumpTrackDetail(
  WidgetTester tester, {
  String trackId = 'seed-01',
  bool asTrackOwner = true,
  Size size = const Size(1280, 2800),
  VoidCallback? onNavigateToStudio,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      overrides: asTrackOwner
          ? [
              currentCreatorIdProvider.overrideWithValue('creator_fifi'),
              currentCreatorHandleProvider.overrideWithValue('@fifi'),
            ]
          : const [],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: TrackDetailView(
          trackId: trackId,
          onNavigateToStudio: onNavigateToStudio,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets(
    'TrackDetailView owner mode renders all studio dissection components & threaded comments',
    (WidgetTester tester) async {
      await _pumpTrackDetail(tester, asTrackOwner: true);

      // 1. Hero Showcase & Owner Deed (`REQ-TRK-02`, `REQ-TRK-03`, `REQ-P70-GATE-01`)
      expect(find.byType(TrackHeroSection), findsOneWidget);
      expect(find.byKey(const Key('track_hero_artwork')), findsOneWidget);
      expect(find.byKey(const Key('track_owner_deed_card')), findsOneWidget);
      expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
      expect(find.textContaining('Amapiano • Tshivenḓa • 3:18'), findsOneWidget);
      expect(find.textContaining('Personal Use'), findsOneWidget);
      expect(find.textContaining('100% royalty-free'), findsOneWidget);
      expect(find.text('Fifi'), findsOneWidget);

      // 2. Social Action Bar (`REQ-TRK-04`)
      expect(find.byType(TrackActionsBar), findsOneWidget);
      expect(find.text('Remix'), findsOneWidget);
      expect(find.text('Tip'), findsOneWidget);

      // 3. Utility Dock (`REQ-TRK-05`)
      expect(find.byType(UtilityToolDock), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Radio'), findsOneWidget);

      // 4. Compact Horizontal Cultural Vector Reactions (`REQ-TRK-06`)
      expect(find.byType(EmojiReactionDeck), findsOneWidget);
      expect(find.byKey(const Key('track_reaction_rail')), findsOneWidget);
      expect(find.byKey(const Key('reaction_fire')), findsOneWidget);
      expect(find.byKey(const Key('reaction_love')), findsOneWidget);

      // 5. Amplitude Waveform Scrubber (`REQ-TRK-07`, Phosphor icon)
      expect(find.byType(WaveformScrubber), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WaveformScrubber),
          matching: find.byIcon(PhosphorIconsFill.playCircle),
        ),
        findsOneWidget,
      );

      // 6. Structured Telemetry Card & Lyrics Teleprompter
      expect(find.byType(TrackSonicTelemetryCard), findsOneWidget);
      expect(find.byType(LyricsTeleprompter), findsOneWidget);
      expect(find.text('Lyrics'), findsOneWidget);
      expect(
        find.textContaining('Moonlight falls on your shoulder'),
        findsOneWidget,
      );

      // 7. Stem Separation Lab & Prompt Attribution (`REQ-TRK-09`, `REQ-TRK-10`)
      expect(find.byType(StemSeparationLab), findsOneWidget);
      expect(find.text('Stem Separation Lab'), findsOneWidget);
      expect(find.text('Separate'), findsOneWidget);
      expect(find.byType(PromptAttributionCard), findsOneWidget);
      expect(find.text('PROMPT'), findsOneWidget);
      expect(find.text('Remix Prompt'), findsOneWidget);

      // 8. Phase 69 Shared Threaded Comments (`EP-P69-THREADED-COMMENTS`)
      expect(find.byType(ThreadedCommentsSection), findsOneWidget);
      expect(find.byType(StudioReactionComposerBar), findsOneWidget);

      // 9. More Like This Shelf (`REQ-TRK-11`)
      expect(find.byType(MoreLikeThisShelf), findsOneWidget);
      expect(find.text('More Like This'), findsOneWidget);
    },
  );

  testWidgets('TrackDetailView toggles like and updates like count', (
    WidgetTester tester,
  ) async {
    await _pumpTrackDetail(tester);

    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    final likeButton = find.byKey(const Key('track_like_pill'));
    await tester.tap(likeButton);
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.tap(likeButton);
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.descendant(
        of: find.byType(TrackActionsBar),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'TrackDetailView submits threaded comment via StudioReactionComposerBar',
    (WidgetTester tester) async {
      await _pumpTrackDetail(tester);

      final commentField = find.descendant(
        of: find.byType(StudioReactionComposerBar),
        matching: find.byType(TextField),
      );
      expect(commentField, findsOneWidget);

      await tester.enterText(commentField, 'Mindblowing sound design!');
      final sendButton = find.byKey(const Key('comment_send_btn'));
      await tester.ensureVisible(sendButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(sendButton);
      await tester.pump(const Duration(milliseconds: 220));

      expect(
        find.textContaining('Mindblowing sound design!', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TrackDetailView stem separation triggers simulation and extracts 4 stems',
    (WidgetTester tester) async {
      await _pumpTrackDetail(tester, asTrackOwner: true);

      final extractButton = find.text('Separate');
      expect(extractButton, findsOneWidget);

      await tester.tap(extractButton);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.descendant(
          of: find.byType(StemSeparationLab),
          matching: find.text('Vocals'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StemSeparationLab),
          matching: find.text('Drums'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StemSeparationLab),
          matching: find.text('Bass & Log Drums'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StemSeparationLab),
          matching: find.text('Instrumental'),
        ),
        findsOneWidget,
      );
    },
  );
}

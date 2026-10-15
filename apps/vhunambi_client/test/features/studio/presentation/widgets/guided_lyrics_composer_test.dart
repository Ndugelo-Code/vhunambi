import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/guided_lyrics_composer.dart';

void main() {
  testWidgets('GuidedLyricsComposer renders steps, section editor and atmosphere chips', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: GuidedLyricsComposer(
              onDone: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(GuidedLyricsComposer.composerKey), findsOneWidget);
    expect(find.text('Guided Lyrics Composer'), findsOneWidget);
    expect(find.text('1 of 6'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);

    // Enter lines for Intro
    await tester.enterText(
      find.byKey(const Key('guided_section_input_Intro')),
      'Sunrise over Soweto\nLog drums start to pulse',
    );
    await tester.pump();

    // Tap Next
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // Verify moved to Verse 1
    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('Verse 1'), findsOneWidget);

    // Verify back button is present on step 2
    expect(find.text('← Back'), findsOneWidget);
  });

  testWidgets('GuidedLyricsComposer completes through sections and assembles customLyrics', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var doneCalled = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GuidedLyricsComposer(
              onDone: () => doneCalled = true,
            ),
          ),
        ),
      ),
    );

    // Intro
    await tester.enterText(
      find.byKey(const Key('guided_section_input_Intro')),
      'Intro line 1',
    );
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // Verse 1
    await tester.enterText(
      find.byKey(const Key('guided_section_input_Verse 1')),
      'Verse 1 line 1',
    );
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // Chorus
    await tester.enterText(
      find.byKey(const Key('guided_section_input_Chorus')),
      'Chorus catchy chant',
    );
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // Verse 2 (Optional) -> Skip
    expect(find.byKey(const Key('guided_composer_skip_btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('guided_composer_skip_btn')));
    await tester.pumpAndSettle();

    // Bridge (Optional) -> Skip
    expect(find.byKey(const Key('guided_composer_skip_btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('guided_composer_skip_btn')));
    await tester.pumpAndSettle();

    // Outro (Last section)
    expect(find.text('6 of 6'), findsOneWidget);
    expect(find.text('Outro'), findsOneWidget);
    expect(find.text('Finish & Apply ➔'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('guided_section_input_Outro')),
      'Fade into the morning light',
    );
    await tester.tap(find.text('Finish & Apply ➔'));
    await tester.pumpAndSettle();

    expect(doneCalled, isTrue);

    final form = container.read(studioFormProvider);
    expect(form.customLyrics, contains('[Intro]\nIntro line 1'));
    expect(form.customLyrics, contains('[Chorus]\nChorus catchy chant'));
    expect(form.customLyrics, contains('[Outro]\nFade into the morning light'));
  });
}

void _noop() {}

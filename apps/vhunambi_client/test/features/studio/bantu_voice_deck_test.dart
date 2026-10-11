import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/bantu_voice_profile.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/bantu_voice_deck.dart';

void main() {
  testWidgets('renders all 5 native timbre profile cards', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: SingleChildScrollView(child: BantuVoiceDeck())),
        ),
      ),
    );

    expect(find.text('Bantu Voice LoRA Engine'), findsOneWidget);
    expect(find.text('5 Native Dialects'), findsOneWidget);
    for (final profile in kBantuVoiceProfiles) {
      expect(find.byKey(ValueKey('timbre_${profile.id}')), findsOneWidget);
    }
    expect(find.byType(Slider), findsNWidgets(4));
  });

  testWidgets('tapping a timbre card updates the selected voice profile',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: SingleChildScrollView(child: BantuVoiceDeck())),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('timbre_soweto_soul_lead')));
    await tester.pumpAndSettle();

    expect(container.read(studioFormProvider).selectedVoiceProfile.id,
        'soweto_soul_lead');
  });

  testWidgets('dragging a dialect slider updates inflection state',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: SingleChildScrollView(child: BantuVoiceDeck())),
        ),
      ),
    );

    final before = container.read(studioFormProvider).dialectInflection.vowelElongation;
    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();
    final after = container.read(studioFormProvider).dialectInflection.vowelElongation;

    expect(after, isNot(before));
  });
}

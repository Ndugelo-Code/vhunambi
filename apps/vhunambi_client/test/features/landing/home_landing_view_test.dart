import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/landing/presentation/views/home_landing_view.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/heritage_genre_showcase.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/how_it_works_section.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/landing_hero_section.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/pricing_matrix_section.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';

Future<void> _pumpLanding(
  WidgetTester tester, {
  Size size = const Size(1280, 3400),
  VoidCallback? onGetStarted,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeLandingView(onGetStarted: onGetStarted),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeLandingView)));

void main() {
  testWidgets('Desktop landing funnel renders every section',
      (WidgetTester tester) async {
    await _pumpLanding(tester);

    // Hero (REQ-MKT-07)
    expect(find.text(LandingHeroSection.badgeLabel), findsOneWidget);
    expect(
      find.text('Create African Music with a Single Prompt'),
      findsOneWidget,
    );
    expect(find.text(LandingHeroSection.subtitle), findsOneWidget);
    expect(find.text(LandingHeroSection.promptHint), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('Limpopo Sunset'), findsOneWidget);
    expect(find.text('Amapiano • Tshivenḓa'), findsOneWidget);

    // Social proof counters (REQ-MKT-08)
    expect(find.text('210+'), findsOneWidget);
    expect(find.text('27+'), findsOneWidget);
    expect(find.text('1,008'), findsOneWidget);
    expect(find.text('Songs Created'), findsOneWidget);

    // How it works (REQ-MKT-08)
    expect(find.text(HowItWorksSection.title), findsOneWidget);
    expect(find.text('01 ✍️'), findsOneWidget);
    expect(find.text('Describe your song'), findsOneWidget);
    expect(find.text('02 ⚡'), findsOneWidget);
    expect(find.text('AI generates it'), findsOneWidget);
    expect(find.text('03 🚀'), findsOneWidget);
    expect(find.text('Share with the world'), findsOneWidget);
    expect(find.text(HowItWorksSection.ctaLabel), findsOneWidget);

    // Heritage genre showcase (REQ-MKT-09)
    expect(find.text(HeritageGenreShowcase.title), findsOneWidget);
    expect(find.text('Amapiano'), findsOneWidget);
    expect(find.text('West Africa'), findsOneWidget);
    expect(find.text('Central Africa'), findsOneWidget);

    // Value pillars (REQ-MKT-09)
    expect(find.text('AI-Powered Generation'), findsOneWidget);
    expect(find.text('Multilingual Linguistic Engine'), findsOneWidget);
    expect(find.text('African Genres First'), findsOneWidget);
    expect(find.text('Collaborate in Real Time'), findsOneWidget);
    expect(find.text('Download & Full Ownership'), findsOneWidget);
    expect(find.text('Direct WhatsApp & Social Sharing'), findsOneWidget);

    // Cultural translation spotlight + testimonials (REQ-MKT-10)
    expect(find.text('Generic AI Translation'), findsNothing);
    expect(find.text('❌ Generic AI Translation'), findsOneWidget);
    expect(find.text('✅ Vhunambi Indigenous Synthesis'), findsOneWidget);
    expect(find.textContaining('Thohoyandou, Limpopo'), findsOneWidget);
    expect(find.textContaining('Nairobi, Kenya'), findsOneWidget);
    expect(find.textContaining('Lagos, Nigeria'), findsOneWidget);

    // Pricing matrix (REQ-MKT-11)
    expect(find.text(PricingMatrixSection.title), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly - Save 20%'), findsOneWidget);
    expect(find.text('Most Popular'), findsOneWidget);
    expect(find.text('\$29'), findsOneWidget);
    expect(find.text('\$119'), findsOneWidget);

    // Footer (REQ-MKT-11)
    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Commercial Licensing'), findsOneWidget);
  });

  testWidgets('Hero prompt is pushed into the Studio cockpit',
      (WidgetTester tester) async {
    var studioRequests = 0;
    await _pumpLanding(tester, onGetStarted: () => studioRequests++);
    final container = _containerOf(tester);

    await tester.enterText(
      find.byType(TextField),
      'Late-night log drum anthem in Tshivenḓa',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(studioRequests, 1);
    expect(
      container.read(studioFormProvider).prompt,
      'Late-night log drum anthem in Tshivenḓa',
    );
  });

  testWidgets('Empty hero prompt does not route to the studio',
      (WidgetTester tester) async {
    var studioRequests = 0;
    await _pumpLanding(tester, onGetStarted: () => studioRequests++);

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(studioRequests, 0);
    expect(
      find.text('Describe your song first — then hit Generate.'),
      findsOneWidget,
    );
  });

  testWidgets('Billing toggle switches the pricing matrix to yearly rates',
      (WidgetTester tester) async {
    await _pumpLanding(tester);

    expect(find.text('\$29'), findsOneWidget);
    expect(find.text('\$23'), findsNothing);

    await tester.tap(find.text('Yearly - Save 20%'));
    await tester.pumpAndSettle();

    expect(find.text('\$23'), findsOneWidget);
    expect(find.text('\$95'), findsOneWidget);
    expect(find.text('\$29'), findsNothing);
    expect(find.text('/mo billed yearly'), findsNWidgets(4));
  });

  testWidgets('Regional tab scopes the heritage genre showcase',
      (WidgetTester tester) async {
    await _pumpLanding(tester);

    expect(find.text('Mbaqanga'), findsOneWidget);
    expect(find.text('Highlife'), findsOneWidget);

    await tester.tap(find.text('West Africa'));
    await tester.pumpAndSettle();

    expect(find.text('Highlife'), findsOneWidget);
    expect(find.text('Mbaqanga'), findsNothing);
    expect(find.text('Amapiano'), findsNothing);
  });

  testWidgets('Genre chip auditions a matching marketplace preview',
      (WidgetTester tester) async {
    await _pumpLanding(tester);
    final container = _containerOf(tester);

    await tester.tap(find.text('Gqom'));
    await tester.pumpAndSettle();

    expect(
      container.read(playerStateProvider).currentTrack?.id,
      'beat_durban_midnight',
    );
    expect(
      find.text('Auditioning "Durban Midnight Bass" — Gqom preview.'),
      findsOneWidget,
    );
  });

  testWidgets('Mobile landing stacks the funnel and scrolls to pricing',
      (WidgetTester tester) async {
    await _pumpLanding(tester, size: const Size(420, 2400));

    expect(find.text(LandingHeroSection.badgeLabel), findsOneWidget);
    expect(
      find.text('Create African Music with a Single Prompt'),
      findsOneWidget,
    );
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('210+'), findsOneWidget);
    expect(find.text(HowItWorksSection.title), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(PricingMatrixSection.title),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text(PricingMatrixSection.title), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });
}

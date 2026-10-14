// T7.3 — DnaInsightCard widget tests (REQ-DNA-HOME-01, REQ-DNA-HOME-03)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/dna_insight_card.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

void main() {
  group('DnaInsightCard', () {
    testWidgets('renders Keep exploring tip when lifecycleState is seeded', (tester) async {
      final seededDna = CreatorDnaProfile.initial().copyWith(
        lifecycleState: DnaLifecycleState.seeded,
        onboardingCompleted: true,
        genreWeights: {'Amapiano': 0.5},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creatorDnaProvider.overrideWith(
              (ref) => CreatorDnaNotifier.withInitial(seededDna),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DnaInsightCard(animatedMeter: false)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dna_insight_card')), findsOneWidget);
      expect(find.textContaining('Keep exploring'), findsOneWidget);
    });

    testWidgets('dismiss button has 44x44 minimum hit area', (tester) async {
      final seededDna = CreatorDnaProfile.initial().copyWith(
        lifecycleState: DnaLifecycleState.seeded,
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creatorDnaProvider.overrideWith(
              (ref) => CreatorDnaNotifier.withInitial(seededDna),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DnaInsightCard(animatedMeter: false)),
          ),
        ),
      );
      await tester.pump();

      final dismissBtn = find.byKey(const Key('dna_insight_card_dismiss_button'));
      expect(dismissBtn, findsOneWidget);

      final size = tester.getSize(dismissBtn);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('card is hidden when dnaInsightCardDismissed is true', (tester) async {
      final dismissedDna = CreatorDnaProfile.initial().copyWith(
        dnaInsightCardDismissed: true,
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creatorDnaProvider.overrideWith(
              (ref) => CreatorDnaNotifier.withInitial(dismissedDna),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DnaInsightCard(animatedMeter: false)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dna_insight_card')), findsNothing);
    });

    test('tipTextFor returns correct tip for each lifecycle state', () {
      final dna = CreatorDnaProfile.initial();

      expect(
        DnaInsightCard.tipTextFor(dna.copyWith(lifecycleState: DnaLifecycleState.seeded)),
        contains('Keep exploring'),
      );
      expect(
        DnaInsightCard.tipTextFor(dna.copyWith(lifecycleState: DnaLifecycleState.calibrated)),
        contains('studio defaults'),
      );
      expect(
        DnaInsightCard.tipTextFor(dna.copyWith(lifecycleState: DnaLifecycleState.attuned)),
        contains('knows your sound'),
      );
      expect(
        DnaInsightCard.tipTextFor(dna.copyWith(lifecycleState: DnaLifecycleState.uninitialized)),
        contains('Complete onboarding'),
      );
    });
  });
}

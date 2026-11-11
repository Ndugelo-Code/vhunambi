import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/heritage_crate_models.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/crate_browser_deck.dart';

void main() {
  testWidgets('renders search, category chips, and sample cards',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: CrateBrowserDeck()),
        ),
      ),
    );

    expect(find.text('Heritage Crate Digging'), findsOneWidget);
    expect(find.byKey(const Key('crate_search_field')), findsOneWidget);
    for (final cat in HeritageCrateCategory.values) {
      expect(find.byKey(ValueKey('crate_cat_${cat.name}')), findsOneWidget);
    }
    // Seeded sample cards render audition/chop controls.
    expect(find.byKey(const Key('audition_sample_mbira_01')), findsOneWidget);
    expect(find.byKey(const Key('chop_sample_mbira_01')), findsOneWidget);
  });

  testWidgets('tapping a category chip filters samples', (tester) async {
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
          home: const Scaffold(body: CrateBrowserDeck()),
        ),
      ),
    );

    await tester.tap(
        find.byKey(const ValueKey('crate_cat_melodicIdiophones')));
    await tester.pump();

    expect(container.read(heritageCrateProvider).activeCategory,
        HeritageCrateCategory.melodicIdiophones);
    // Mbira is tagged 'mbira' -> matches the idiophones category.
    expect(
      container
          .read(heritageCrateProvider)
          .filteredSamples
          .any((s) => s.id == 'sample_mbira_01'),
      isTrue,
    );
  });

  testWidgets('tapping audition flips the playing state', (tester) async {
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
          home: const Scaffold(body: CrateBrowserDeck()),
        ),
      ),
    );

    expect(container.read(heritageCrateProvider).auditioningSampleId, isNull);
    await tester.tap(find.byKey(const Key('audition_sample_mbira_01')));
    await tester.pump();
    expect(container.read(heritageCrateProvider).auditioningSampleId,
        'sample_mbira_01');

    // Stop audition so the spinning-vinyl controller does not leak a ticker.
    await tester.tap(find.byKey(const Key('audition_sample_mbira_01')));
    await tester.pump();
    expect(container.read(heritageCrateProvider).auditioningSampleId, isNull);
  });

  testWidgets('tapping Chop slices the sample and fires the callback',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    HeritageSampleEntity? chopped;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CrateBrowserDeck(onChop: (s) => chopped = s),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chop_sample_mbira_01')));
    await tester.pump();

    expect(chopped?.id, 'sample_mbira_01');
    // sliceSample repopulated the MPC pads with the source title.
    expect(container.read(mpcSlicerProvider).sourceTitle,
        'Mbira DzaVadzimu Spiritual Ostinato');
    expect(container.read(mpcSlicerProvider).pads.length, 8);
  });
}

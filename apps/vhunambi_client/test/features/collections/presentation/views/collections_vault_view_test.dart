import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/collections/data/repositories/in_memory_collection_repository.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/presentation/providers/collections_provider.dart';
import 'package:vhunambi_client/features/collections/presentation/views/collection_detail_view.dart';
import 'package:vhunambi_client/features/collections/presentation/views/collections_vault_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';

/// T13 — CollectionsVaultView widget suite (REQ-COL-31).
void main() {
  group('CollectionsVaultView', () {
    testWidgets('renders the universal empty state and its CTA',
        (tester) async {
      await _pumpVault(tester);

      expect(find.text('No collections yet'), findsOneWidget);
      expect(find.text('Start a collection'), findsOneWidget);
    });

    testWidgets('tapping the empty state CTA opens the create dialog',
        (tester) async {
      await _pumpVault(tester);

      await tester.tap(find.text('Start a collection'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Collection'), findsOneWidget);
      expect(find.text('Collection Title'), findsOneWidget);
      expect(find.text('Collection Type'), findsOneWidget);
    });

    testWidgets('renders grid cards with badge, title and track count',
        (tester) async {
      await _pumpVault(tester, seed: [_collection(trackIds: const ['t1', 't2'])]);

      expect(find.text('Ẓe Amapiano EP'), findsOneWidget);
      expect(find.text('EP'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('New Collection'), findsOneWidget);
    });

    testWidgets('renders Material list rows in list view mode',
        (tester) async {
      await _pumpVault(
        tester,
        seed: [_collection(trackIds: const ['t1', 't2', 't3'])],
        viewMode: LibraryViewMode.list,
      );

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('3 songs • EP'), findsOneWidget);
    });

    testWidgets('search filters the vault by title and genre', (tester) async {
      await _pumpVault(
        tester,
        seed: [
          _collection(id: 'col_1', title: 'Amapiano Grooves', genre: 'Amapiano'),
          _collection(id: 'col_2', title: 'Maskandi Heritage', genre: 'Maskandi'),
        ],
      );

      expect(find.text('Amapiano Grooves'), findsOneWidget);
      expect(find.text('Maskandi Heritage'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('collection_search')), 'Gqom');
      await tester.pumpAndSettle();

      expect(find.textContaining('No collections match'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('collection_search')), 'Maskandi');
      await tester.pumpAndSettle();

      expect(find.text('Maskandi Heritage'), findsOneWidget);
      expect(find.text('Amapiano Grooves'), findsNothing);
    });

    testWidgets('tapping a collection card navigates to the detail view',
        (tester) async {
      await _pumpVault(tester, seed: [_collection(title: 'Deep House Sunset')]);

      await tester.tap(find.text('Deep House Sunset'));
      await tester.pumpAndSettle();

      expect(find.byType(CollectionDetailView), findsOneWidget);
      expect(find.text('📄 Split Sheet'), findsOneWidget);
    });

    testWidgets('the New Collection button creates a collection',
        (tester) async {
      await _pumpVault(tester, seed: [_collection()]);

      await tester.tap(find.byKey(const Key('new_collection_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('collection_title_field')),
        'Gqom Heat Album',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection_dialog_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Gqom Heat Album'), findsOneWidget);
      expect(find.text('Create New Collection'), findsNothing);
    });

    testWidgets('the library collections tab mounts the collections vault',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            collectionRepositoryProvider.overrideWithValue(
              InMemoryCollectionRepository(seed: [_collection()]),
            ),
            libraryCategoryProvider
                .overrideWith((ref) => LibraryCategory.collections),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LibraryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CollectionsVaultView), findsOneWidget);
      expect(find.text('Ẓe Amapiano EP'), findsOneWidget);
    });
  });
}

/// Pumps [CollectionsVaultView] on a deterministic desktop viewport.
Future<ProviderContainer> _pumpVault(
  WidgetTester tester, {
  List<CollectionEntity> seed = const <CollectionEntity>[],
  LibraryViewMode viewMode = LibraryViewMode.grid,
}) async {
  tester.view.physicalSize = const Size(1280, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: <Override>[
      collectionRepositoryProvider.overrideWithValue(
        InMemoryCollectionRepository(seed: seed),
      ),
      libraryViewModeProvider.overrideWith((ref) => viewMode),
    ],
  );
  addTearDown(container.dispose);

  await container.read(collectionsProvider.notifier).loadCollections();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: CollectionsVaultView()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

CollectionEntity _collection({
  String id = 'col_1',
  String title = 'Ẓe Amapiano EP',
  String genre = 'Amapiano',
  List<String> trackIds = const ['t1'],
}) =>
    CollectionEntity(
      id: id,
      title: title,
      genre: genre,
      trackIds: trackIds,
      createdAt: DateTime(2026, 9, 27),
      updatedAt: DateTime(2026, 9, 27),
    );

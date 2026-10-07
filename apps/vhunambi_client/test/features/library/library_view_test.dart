import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/beats/presentation/views/beats_vault_view.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_track_grid_card.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_track_tile.dart';

Future<void> _pumpLibrary(
  WidgetTester tester, {
  Size size = const Size(1280, 1024),
  VoidCallback? onCreateRequested,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: LibraryView(onCreateRequested: onCreateRequested),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Desktop vault renders the header, category rail and seeded vault',
      (WidgetTester tester) async {
    await _pumpLibrary(tester);

    // Sticky responsive header (REQ-LIB-01)
    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('10 songs left'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Category rail (REQ-LIB-02)
    for (final label in const [
      'Songs',
      'Playlists',
      'Collections',
      'Beats',
      'Licensing',
      'Trash',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Seeded vault — vocal releases surface in the default Songs category
    expect(find.byType(LibraryTrackTile), findsNWidgets(2));
    expect(find.text('Grateful in the Light'), findsOneWidget);
    expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
    expect(find.text('Township Log Drum Heat'), findsNothing);
    expect(find.text('2 assets'), findsOneWidget);

    // Offline vs. cloud cache indicators (REQ-LIB-05)
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.textContaining('3:36'), findsOneWidget);
  });

  testWidgets('Mobile vault header keeps only the compact controls',
      (WidgetTester tester) async {
    await _pumpLibrary(tester, size: const Size(420, 900));

    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text('10 songs left'), findsOneWidget);
    // Desktop-only controls are hidden on mobile viewports.
    expect(find.text('My Library'), findsNothing);
    expect(find.text('Analytics'), findsNothing);
    expect(find.text('Create'), findsNothing);
    // The create action collapses to a square sparkle button.
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(LibraryTrackTile), findsNWidgets(2));
  });

  testWidgets('Category tabs scope the vault and drive the universal empty state',
      (WidgetTester tester) async {
    await _pumpLibrary(tester);

    await tester.tap(find.text('Beats'));
    await tester.pumpAndSettle();
    // REQ-BEAT-14 supersedes the Phase 4 library-tab stub: the Beats tab now
    // mounts the Producer Beats Vault, which reads its own beat repository
    // (empty in a headless run) rather than the song vault.
    expect(find.byType(BeatsVaultView), findsOneWidget);
    expect(find.text('Search my beats...'), findsOneWidget);
    expect(find.text('New Beat'), findsOneWidget);
    expect(find.text('No beats yet'), findsOneWidget);
    expect(find.text('Create your first beat'), findsOneWidget);
    expect(find.text('Grateful in the Light'), findsNothing);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(find.text('Create your first playlist'), findsOneWidget);

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(find.text('Back to Songs'), findsOneWidget);
  });

  testWidgets('Search filters titles and creators and can be cleared',
      (WidgetTester tester) async {
    await _pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'fifi');
    await tester.pumpAndSettle();
    expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
    expect(find.text('Grateful in the Light'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches for "zzz"'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Grateful in the Light'), findsOneWidget);
    expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
  });

  testWidgets('View mode toggle swaps dense list rows for square grid cards',
      (WidgetTester tester) async {
    await _pumpLibrary(tester);

    expect(find.byType(LibraryTrackTile), findsNWidgets(2));
    expect(find.byType(LibraryTrackGridCard), findsNothing);

    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTrackGridCard), findsNWidgets(2));
    expect(find.byType(LibraryTrackTile), findsNothing);

    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTrackTile), findsNWidgets(2));
    expect(find.byType(LibraryTrackGridCard), findsNothing);
  });

  testWidgets('Trash action soft-deletes and the Trash tab restores the asset',
      (WidgetTester tester) async {
    await _pumpLibrary(tester);

    // Open the contextual action sheet for the newest song (REQ-LIB-06).
    await tester.tap(find.byTooltip('Asset actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Play Now'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Stem Separation'), findsOneWidget);
    expect(find.text('Download Offline'), findsOneWidget);
    expect(find.text('View Commercial License'), findsOneWidget);
    expect(find.text('Share Song'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);

    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Grateful in the Light'), findsNothing);
    expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);

    // Let the undo snackbar expire so it cannot overlay later taps.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Trash exposes restore + permanent purge (REQ-LIB-07).
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Grateful in the Light'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.byTooltip('Asset actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Restore Track'), findsOneWidget);
    expect(find.text('Delete Permanently'), findsOneWidget);
    expect(find.text('Move to Trash'), findsNothing);

    await tester.tap(find.text('Restore Track'));
    await tester.pumpAndSettle();
    expect(find.text('Trash is empty'), findsOneWidget);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(find.text('Grateful in the Light'), findsOneWidget);
    expect(find.byType(LibraryTrackTile), findsNWidgets(2));
  });

  testWidgets('Empty state CTA requests the Studio cockpit',
      (WidgetTester tester) async {
    var studioRequests = 0;
    await _pumpLibrary(
      tester,
      onCreateRequested: () => studioRequests++,
    );

    // Generic categories keep the Phase 4 Studio handoff (REQ-LIB-03).
    await tester.tap(find.text('Licensing'));
    await tester.pumpAndSettle();
    expect(find.text('No licenses yet'), findsOneWidget);

    await tester.tap(find.text('Create your first song'));
    await tester.pumpAndSettle();
    expect(studioRequests, 1);
  });

  testWidgets('Collections empty state CTA opens the create collection dialog',
      (WidgetTester tester) async {
    var studioRequests = 0;
    await _pumpLibrary(
      tester,
      onCreateRequested: () => studioRequests++,
    );

    // Phase 13 (REQ-COL-13) supersedes the generic CTA for this category:
    // the vault's empty state now launches the Create Collection dialog.
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(find.text('No collections yet'), findsOneWidget);

    await tester.tap(find.text('Start a collection'));
    await tester.pumpAndSettle();
    expect(find.text('Create New Collection'), findsOneWidget);
    expect(studioRequests, 0);
  });
}

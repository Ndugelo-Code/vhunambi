import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/beats/presentation/views/beats_vault_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/track_actions_sheet.dart';
import 'package:vhunambi_client/features/marketplace/data/repositories/http_marketplace_repository.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/reference_audio_dropzone.dart';

class _CustomTestLibraryNotifier extends LibraryTracksNotifier {
  _CustomTestLibraryNotifier(List<LibraryTrack> initial) {
    state = initial;
  }
}

void main() {
  group('Phase 28: Marketplace & Beats Vault Economy Bridge', () {
    test('HttpMarketplaceRepository falls back safely offline and returns catalog', () async {
      final repo = HttpMarketplaceRepository();
      final beats = await repo.getBeats();

      expect(beats.isNotEmpty, isTrue);
      expect(beats.first.title.isNotEmpty, isTrue);
      expect(beats.first.priceInCredits, greaterThan(0));
    });

    test('HttpMarketplaceRepository creates license certificate offline fallback', () async {
      final repo = HttpMarketplaceRepository();
      final res = await repo.licenseBeat(
        beatId: 'market_test_1',
        buyerId: 'user_test_buyer',
        tier: 'exclusive',
      );

      final cert = (res['certificate'] as Map<String, dynamic>?) ?? res;
      expect(cert['beatId'], equals('market_test_1'));
      expect(cert['buyerId'], equals('user_test_buyer'));
      expect(cert['licenseType'], equals('Exclusive Commercial Master License'));
      expect((cert['licenseHash'] as String).isNotEmpty, isTrue);
    });

    test('LibraryCategory.licensing properly filters licensed tracks', () {
      final licensedTrack = LibraryTrack(
        id: 'market_licensed_1',
        title: 'Maputo Deep Amapiano',
        creatorName: 'DJ Maphorisa',
        genre: 'Amapiano',
        language: 'Instrumental',
        durationSeconds: 180,
        remoteAudioUrl: 'https://example.com/audio1.mp3',
        createdAt: DateTime.now(),
        licenseType: 'Exclusive Commercial Master License',
      );

      final uncommercialTrack = LibraryTrack(
        id: 'voice_note_1',
        title: 'Voice Memo',
        creatorName: 'Myself',
        genre: 'Afrobeat',
        language: 'English',
        durationSeconds: 60,
        remoteAudioUrl: 'https://example.com/audio2.mp3',
        createdAt: DateTime.now(),
        licenseType: 'Commercial',
      );

      final container = ProviderContainer(
        overrides: [
          libraryTracksProvider.overrideWith(
            (ref) => _CustomTestLibraryNotifier([licensedTrack, uncommercialTrack]),
          ),
        ],
      );

      container.read(libraryCategoryProvider.notifier).state =
          LibraryCategory.licensing;

      final filtered = container.read(filteredLibraryTracksProvider);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('market_licensed_1'));
    });

    testWidgets('BeatsVaultView renders 2-segment switcher and toggles to licensed beats',
        (tester) async {
      final licensedBeat = LibraryTrack(
        id: 'market_licensed_99',
        title: 'Soweto Groove Instrumental',
        creatorName: 'Kabza De Small',
        genre: 'Amapiano',
        language: 'Instrumental',
        durationSeconds: 240,
        remoteAudioUrl: 'https://example.com/beat99.mp3',
        createdAt: DateTime.now(),
        licenseType: 'Standard Commercial License',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryTracksProvider.overrideWith(
              (ref) => _CustomTestLibraryNotifier([licensedBeat]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: BeatsVaultView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check segmented controls exist
      expect(find.byKey(const Key('beats_vault_mode_produced')), findsOneWidget);
      expect(find.byKey(const Key('beats_vault_mode_licensed')), findsOneWidget);

      // Tap to switch to Licensed Beats
      await tester.tap(find.byKey(const Key('beats_vault_mode_licensed')));
      await tester.pumpAndSettle();

      // Verify the licensed beat is displayed with quick studio CTA
      expect(find.text('Soweto Groove Instrumental'), findsOneWidget);
      expect(
        find.byKey(const Key('licensed_beat_use_in_studio_market_licensed_99')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('licensed_beat_cert_market_licensed_99')),
        findsOneWidget,
      );
    });

    testWidgets('TrackActionsSheet displays List in Beatstore action',
        (tester) async {
      final testTrack = LibraryTrack(
        id: 'track_test_1',
        title: 'Original Studio Mix',
        creatorName: 'Current User',
        genre: 'Amapiano',
        language: 'English',
        durationSeconds: 200,
        remoteAudioUrl: 'https://example.com/mix.mp3',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TrackActionsSheet(
                track: testTrack,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listTile = find.byKey(const Key('track_action_list_in_beatstore'));
      expect(listTile, findsOneWidget);
      expect(find.text('💰 List in Beatstore'), findsOneWidget);
    });

    testWidgets('ReferenceAudioDropzone displays My Beats picker button and opens sheet',
        (tester) async {
      final licensedBeat = LibraryTrack(
        id: 'market_dropzone_beat',
        title: 'Durban Kwaito Loop',
        creatorName: 'Producer X',
        genre: 'Kwaito',
        language: 'Instrumental',
        durationSeconds: 120,
        remoteAudioUrl: 'https://example.com/kwaito.mp3',
        createdAt: DateTime.now(),
        licenseType: 'Commercial License',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryTracksProvider.overrideWith(
              (ref) => _CustomTestLibraryNotifier([licensedBeat]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ReferenceAudioDropzone(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final myBeatsBtn = find.byKey(const Key('dropzone_load_licensed_beat_btn'));
      expect(myBeatsBtn, findsOneWidget);

      await tester.tap(myBeatsBtn);
      await tester.pumpAndSettle();

      // Bottom sheet with licensed beat should appear
      expect(find.text('Choose a Beat as Backing Track'), findsOneWidget);
      expect(find.text('Durban Kwaito Loop'), findsOneWidget);
    });
  });
}

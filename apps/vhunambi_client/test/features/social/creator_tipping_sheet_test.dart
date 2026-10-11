import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_tipping_sheet.dart';

PublishedClip _clip() => PublishedClip(
      id: 'clip_tip_test',
      trackId: 'track_tip',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      title: 'Ndo Mufuna Matibe',
      genre: 'Amapiano',
      audioUrl: 'https://cdn/x.mp3',
      coverUrl: '',
      dna: SongMetadataDna(
        id: 'dna_tip',
        title: 'Ndo Mufuna Matibe',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: const MusicalDna(
            bpm: 113, key: 'Am', energyBracket: 'mid', durationSec: 198),
        vocals: const VocalsDna(
            deliveryMode: 'melodic', gender: 'female', energy: 'mid'),
        visualTheme: const VisualThemeDna(
            mood: 'Cinematic', comfyPrompt: 'amapiano', seed: 42),
      ),
      publishedAt: DateTime.now(),
    );

void main() {
  testWidgets('renders the 4 cultural gifts and coin balance', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: CreatorTippingSheet(clip: _clip())),
        ),
      ),
    );

    expect(find.text('Support @makhadzi'), findsOneWidget);
    expect(find.byKey(const Key('tip_coin_balance')), findsOneWidget);
    expect(find.textContaining('🪙 250'), findsOneWidget);
    expect(find.text('Cowrie Shell (Mbaḓi)'), findsOneWidget);
    expect(find.text('Royal Venda Crown (Khare)'), findsOneWidget);
  });

  testWidgets('sending a gift deducts coins and posts a celebration comment',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final startCoins = container.read(creatorWalletProvider).userCoinsBalance;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: _Host(clip: _clip()),
        ),
      ),
    );

    // Open the sheet from a host route so popping returns to a real Scaffold.
    await tester.tap(find.byKey(const Key('open_tip')));
    await tester.pumpAndSettle();

    // Default selection is the Cowrie Shell (5 coins).
    await tester.tap(find.byKey(const Key('tip_send_btn')));
    await tester.pump();
    await tester.pump();

    expect(container.read(creatorWalletProvider).userCoinsBalance,
        startCoins - 5);
    expect(
      container
          .read(reelsCommentsProvider.notifier)
          .commentsForClip('clip_tip_test'),
      isNotEmpty,
    );

    // Drain the celebration SnackBar timer.
    await tester.pump(const Duration(seconds: 5));
  });
}

class _Host extends StatelessWidget {
  final PublishedClip clip;
  const _Host({required this.clip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open_tip'),
          onPressed: () => CreatorTippingSheet.show(context, clip: clip),
          child: const Text('Tip'),
        ),
      ),
    );
  }
}


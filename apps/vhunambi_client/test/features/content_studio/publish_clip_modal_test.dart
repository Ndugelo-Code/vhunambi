import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/publish_clip_modal.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';

SongMetadataDna _dna() => SongMetadataDna(
      id: 'dna_pub_modal',
      title: 'Makhado Nights',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      musical: const MusicalDna(
        bpm: 114,
        key: 'Am',
        energyBracket: 'mid',
        durationSec: 200,
      ),
      vocals: const VocalsDna(
        deliveryMode: 'melodic',
        gender: 'female',
        energy: 'mid',
      ),
      visualTheme: const VisualThemeDna(
        mood: 'Cinematic',
        comfyPrompt: 'amapiano night drive',
        seed: 7,
        aspectRatio: '9:16',
      ),
    );

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open_publish'),
          onPressed: () {
            ref.read(contentStudioProvider.notifier).initializeWithDna(
                  dna: _dna(),
                  audioUrl: 'https://cdn/makhado-nights.mp3',
                  coverArtUrl: 'https://cdn/makhado-nights.jpg',
                );
            PublishClipModal.show(context);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders caption, tags, visibility and publish controls',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const _Host(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_publish')));
    await tester.pumpAndSettle();

    expect(find.text('Publish to Vhunambi Profile'), findsOneWidget);
    expect(find.byKey(const Key('publish_caption_field')), findsOneWidget);
    expect(find.text('#Amapiano'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.byKey(const Key('publish_reel_btn')), findsOneWidget);
  });

  testWidgets('publishing injects a clip into the feed and celebrates',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final feedBefore = container.read(socialFeedProvider).clips.length;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const _Host(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_publish')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('publish_caption_field')),
      'Golden hour session 🔥',
    );
    await tester.tap(find.text('#Tshivenḓa'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('publish_reel_btn')));
    await tester.pumpAndSettle();

    // The modal closed and the feed grew with the authored clip.
    expect(find.text('Publish to Vhunambi Profile'), findsNothing);
    final feedAfter = container.read(socialFeedProvider).clips;
    expect(feedAfter.length, feedBefore + 1);
    expect(feedAfter.first.caption, 'Golden hour session 🔥');
    expect(feedAfter.first.tags, contains('Tshivenḓa'));
    expect(container.read(contentStudioProvider).publishedShareUrl, isNotNull);
  });
}

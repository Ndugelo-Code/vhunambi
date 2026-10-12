import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/avatar_customization_modal.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_avatar.dart';

void main() {
  group('CreatorAvatar & AvatarCustomizationModal Widget Tests', () {
    testWidgets('CreatorAvatar renders monogram and handles tap',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CreatorAvatar(
              monogram: 'ND',
              onTap: () => tapped = true,
              size: 44,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ND'), findsOneWidget);

      await tester.tap(find.text('ND'));
      expect(tapped, isTrue);
    });

    testWidgets(
        'AvatarCustomizationModal renders presets and updates owner profile avatar',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: Builder(
                    builder: (innerContext) {
                      return ElevatedButton(
                        key: const Key('open_modal_btn'),
                        onPressed: () {
                          AvatarCustomizationModal.show(innerContext);
                        },
                        child: const Text('Open Modal'),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.byKey(const Key('open_modal_btn')));
      await tester.pumpAndSettle();

      // Verify header and presets
      expect(find.text('Creator Profile Avatar'), findsOneWidget);
      expect(find.text('Cultural AI ✨'), findsOneWidget);
      expect(find.text('Amapiano Maestro'), findsOneWidget);
      expect(find.text('Maskandi Bard'), findsOneWidget);

      // Select Amapiano Maestro preset
      await tester.tap(find.byKey(const Key('preset_preset_amapiano')));
      await tester.pumpAndSettle();

      // Apply Avatar
      await tester.tap(find.byKey(const Key('apply_avatar_button')));
      await tester.pumpAndSettle();

      // Verify owner profile received the avatar URL
      final owner = container.read(ownerProfileProvider);
      expect(owner.avatarUrl, contains('images.unsplash.com'));
    });

    testWidgets('AvatarCustomizationModal allows reverting to monogram',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (innerContext) {
                  return ElevatedButton(
                    key: const Key('open_modal_btn'),
                    onPressed: () {
                      AvatarCustomizationModal.show(innerContext);
                    },
                    child: const Text('Open Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container =
          ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
      container
          .read(ownerProfileProvider.notifier)
          .updateAvatar('https://example.com/avatar.png');
      await tester.pumpAndSettle();

      expect(container.read(ownerProfileProvider).avatarUrl, isNotNull);

      // Open modal
      await tester.tap(find.byKey(const Key('open_modal_btn')));
      await tester.pumpAndSettle();

      // Tap "Revert to Monogram"
      await tester.tap(find.text('Revert to Monogram'));
      await tester.pumpAndSettle();

      // Verify avatarUrl is now null
      expect(container.read(ownerProfileProvider).avatarUrl, isNull);
    });
  });
}

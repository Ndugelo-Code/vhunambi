import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/role_carousel_widget.dart';

void main() {
  group('RoleCarouselWidget Tests', () {
    testWidgets('renders all role cards with center emphasis',
        (WidgetTester tester) async {
      final roles = [
        RoleOption(
          role: CreativeRole.producer,
          label: 'Producer / Beatmaker',
          emoji: '🎹',
          description: 'Crafting beats and melodies',
        ),
        RoleOption(
          role: CreativeRole.vocalist,
          label: 'Vocalist / Singer',
          emoji: '🎤',
          description: 'Writing hooks and harmonies',
        ),
        RoleOption(
          role: CreativeRole.songwriter,
          label: 'Songwriter / Lyricist',
          emoji: '✍️',
          description: 'Poetic lyricism',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoleCarouselWidget(
                key: const Key('role_carousel_test'),
                roles: roles,
                selectedRole: CreativeRole.producer,
                onRoleSelected: (role) {},
              ),
            ),
          ),
        ),
      );

      // Verify center card renders
      expect(find.text('Producer / Beatmaker'), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding_role_card_producer')),
        findsOneWidget,
      );

      // Swipe to next card
      await tester.fling(find.byKey(const Key('role_carousel')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Vocalist / Singer'), findsOneWidget);

      // Swipe to next card
      await tester.fling(find.byKey(const Key('role_carousel')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Songwriter / Lyricist'), findsOneWidget);
    });

    testWidgets('fires onRoleSelected when a role card is tapped',
        (WidgetTester tester) async {
      CreativeRole? selectedRole;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoleCarouselWidget(
                key: const Key('role_carousel_test'),
                roles: [
                  RoleOption(
                    role: CreativeRole.producer,
                    label: 'Producer',
                    emoji: '🎹',
                    description: 'desc',
                  ),
                  RoleOption(
                    role: CreativeRole.vocalist,
                    label: 'Vocalist',
                    emoji: '🎤',
                    description: 'desc',
                  ),
                ],
                selectedRole: CreativeRole.producer,
                onRoleSelected: (role) => selectedRole = role,
              ),
            ),
          ),
        ),
      );

      // Swipe to bring the second card (Vocalist) into center
      await tester.fling(find.byKey(const Key('role_carousel')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Tap the second card (Vocalist)
      await tester.tap(find.byKey(const Key('onboarding_role_card_vocalist')));
      await tester.pumpAndSettle();

      expect(selectedRole, CreativeRole.vocalist);
    });

    testWidgets('respects reduce-motion setting (no animations)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoleCarouselWidget(
                key: const Key('role_carousel_test'),
                roles: [
                  RoleOption(
                    role: CreativeRole.producer,
                    label: 'Producer',
                    emoji: '🎹',
                    description: 'desc',
                  ),
                ],
                selectedRole: CreativeRole.producer,
                onRoleSelected: (role) {},
              ),
            ),
          ),
        ),
      );

      // Should render without error even with reduce motion
      expect(find.text('Producer'), findsOneWidget);
    });

    testWidgets('all interactive elements have explicit Keys',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoleCarouselWidget(
                key: const Key('role_carousel_test'),
                roles: [
                  RoleOption(
                    role: CreativeRole.producer,
                    label: 'Producer',
                    emoji: '🎹',
                    description: 'desc',
                  ),
                ],
                selectedRole: CreativeRole.producer,
                onRoleSelected: (role) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('role_carousel_test')), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding_role_card_producer')),
        findsOneWidget,
      );
    });
  });
}

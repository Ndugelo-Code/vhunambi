import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/player_obstacle.dart';

void main() {
  group('PlayerObstacle Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('registers obstacle on layout', (WidgetTester tester) async {
      final controller = MiniPlayerController();
      await controller.loadState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniPlayerControllerProvider
                .overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerObstacle(
                id: 'test_obstacle',
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Obstacle should be registered after post-frame callback
      expect(
        controller.obstacles.containsKey('test_obstacle'),
        isTrue,
      );
    });

    testWidgets('unregisters obstacle on dispose', (WidgetTester tester) async {
      final controller = MiniPlayerController();
      await controller.loadState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniPlayerControllerProvider
                .overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerObstacle(
                id: 'test_obstacle_2',
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.obstacles.containsKey('test_obstacle_2'), isTrue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniPlayerControllerProvider
                .overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Container(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.obstacles.containsKey('test_obstacle_2'), isFalse);
    });

    testWidgets('renders child widget', (WidgetTester tester) async {
      final controller = MiniPlayerController();
      await controller.loadState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniPlayerControllerProvider
                .overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerObstacle(
                id: 'test_obstacle_3',
                child: const Text('Obstacle Child'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Obstacle Child'), findsOneWidget);
    });
  });
}

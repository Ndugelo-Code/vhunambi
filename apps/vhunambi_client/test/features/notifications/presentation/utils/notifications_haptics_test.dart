import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/notifications/presentation/utils/notifications_haptics.dart';

/// M8 — NotificationsHaptics suite.
///
/// All methods must execute cleanly in the headless VM test runner without
/// throwing (missing plugin channel / platform exceptions are swallowed).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationsHaptics', () {
    test('bellRing runs cleanly without throwing', () async {
      await expectLater(NotificationsHaptics.bellRing(), completes);
    });

    test('dismissSnap runs cleanly without throwing', () async {
      await expectLater(NotificationsHaptics.dismissSnap(), completes);
    });

    test('categorySwitch runs cleanly without throwing', () async {
      await expectLater(NotificationsHaptics.categorySwitch(), completes);
    });

    test('markAllReadPulse runs cleanly without throwing', () async {
      await expectLater(NotificationsHaptics.markAllReadPulse(), completes);
    });

    test('itemTap runs cleanly without throwing', () async {
      await expectLater(NotificationsHaptics.itemTap(), completes);
    });

    test('every semantic method completes concurrently without error',
        () async {
      await Future.wait<void>(<Future<void>>[
        NotificationsHaptics.bellRing(),
        NotificationsHaptics.dismissSnap(),
        NotificationsHaptics.categorySwitch(),
        NotificationsHaptics.markAllReadPulse(),
        NotificationsHaptics.itemTap(),
      ]);
    });
  });
}

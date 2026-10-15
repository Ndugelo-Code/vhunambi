import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/presentation/utils/studio_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioHaptics', () {
    tearDown(() {
      StudioHaptics.setEnabled(true);
    });

    test('all haptic methods execute cleanly without throwing on headless VM', () async {
      await expectLater(StudioHaptics.ignitionThump(), completes);
      await expectLater(StudioHaptics.deckSwitch(), completes);
      await expectLater(StudioHaptics.chipSnap(), completes);
      await expectLater(StudioHaptics.sliderTick(), completes);
      await expectLater(StudioHaptics.successPulse(), completes);
    });

    test('setEnabled toggles isEnabled state', () {
      expect(StudioHaptics.isEnabled, isTrue);
      StudioHaptics.setEnabled(false);
      expect(StudioHaptics.isEnabled, isFalse);
      StudioHaptics.setEnabled(true);
      expect(StudioHaptics.isEnabled, isTrue);
    });

    test('methods silently no-op when disabled', () async {
      StudioHaptics.setEnabled(false);
      await expectLater(StudioHaptics.ignitionThump(), completes);
      await expectLater(StudioHaptics.chipSnap(), completes);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    setUp(() {
      FeatureFlags.reset();
    });

    test('default flag states align with resilient production baseline', () {
      expect(FeatureFlags.useEnhancedErrorHandling, isTrue);
      expect(FeatureFlags.useSkeletonScreens, isTrue);
      expect(FeatureFlags.useAccessibilityEnhancements, isTrue);
      expect(FeatureFlags.enableA11yAuditMode, isFalse);
    });

    test('reset() restores flags to default values', () {
      FeatureFlags.useEnhancedErrorHandling = false;
      FeatureFlags.enableA11yAuditMode = true;

      expect(FeatureFlags.useEnhancedErrorHandling, isFalse);
      expect(FeatureFlags.enableA11yAuditMode, isTrue);

      FeatureFlags.reset();

      expect(FeatureFlags.useEnhancedErrorHandling, isTrue);
      expect(FeatureFlags.enableA11yAuditMode, isFalse);
    });
  });
}

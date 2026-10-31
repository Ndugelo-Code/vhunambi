import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

void main() {
  group('Creator ID Utilities (Task 30.1)', () {
    test(
      'extractRawCreatorId handles bare, single, and recursive prefix permutations',
      () {
        expect(extractRawCreatorId('sigwa'), 'sigwa');
        expect(extractRawCreatorId('creator_sigwa'), 'sigwa');
        expect(extractRawCreatorId('creator_creator_sigwa'), 'sigwa');
        expect(extractRawCreatorId('creator_creator_creator_sigwa'), 'sigwa');
        expect(extractRawCreatorId('  creator_makhadzi  '), 'makhadzi');
        expect(extractRawCreatorId(''), '');
      },
    );

    test('normalizeCreatorId produces canonical creator_<id> idempotently', () {
      expect(normalizeCreatorId('sigwa'), 'creator_sigwa');
      expect(normalizeCreatorId('creator_sigwa'), 'creator_sigwa');
      expect(normalizeCreatorId('creator_creator_sigwa'), 'creator_sigwa');
      expect(
        normalizeCreatorId('creator_creator_creator_sigwa'),
        'creator_sigwa',
      );
      expect(normalizeCreatorId('  makhadzi  '), 'creator_makhadzi');
      expect(normalizeCreatorId(''), '');
    });
  });
}

import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/utils/nep_record_merge_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NepRecordMergeHelper', () {
    test('resolveConflict conserva el registro mas reciente', () {
      final older = NepRecord(
        id: '1',
        telar: '10',
        neps: 5,
        tela: 'A',
        loteTrama: '63E26401',
        createdAt: DateTime(2026, 1, 1),
      );
      final newer = NepRecord(
        id: '1',
        telar: '11',
        neps: 8,
        tela: 'B',
        loteTrama: '63E26402',
        createdAt: DateTime(2026, 2, 1),
      );

      final result = NepRecordMergeHelper.resolveConflict(older, newer);
      expect(result.telar, '11');
      expect(result.neps, 8);
    });

    test('mergeById combina listas sin duplicar ids', () {
      final base = [
        NepRecord(
          id: '1',
          telar: '10',
          neps: 5,
          tela: 'A',
          loteTrama: '63E26401',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      final incoming = [
        NepRecord(
          id: '1',
          telar: '11',
          neps: 8,
          tela: 'B',
          loteTrama: '63E26402',
          createdAt: DateTime(2026, 2, 1),
        ),
        NepRecord(
          id: '2',
          telar: '20',
          neps: 3,
          tela: 'C',
          loteTrama: '63E26403',
          createdAt: DateTime(2026, 3, 1),
        ),
      ];

      final merged = NepRecordMergeHelper.mergeById(base, incoming);

      expect(merged, hasLength(2));
      expect(merged.first.id, '1');
      expect(merged.first.telar, '11');
      expect(merged.last.id, '2');
    });
  });
}

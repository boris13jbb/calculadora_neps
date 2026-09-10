import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/utils/analytics_records_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedReport parseo tolerante', () {
    test('omite registros malformados y conserva el informe', () {
      final report = SavedReport.fromJson({
        'id': 'rep1',
        'name': 'Parcial',
        'createdAt': '2026-01-01T00:00:00.000',
        'records': [
          {
            'id': 'ok',
            'telar': '1',
            'neps': 10,
            'tela': 'A',
            'loteTrama': 'L',
          },
          'basura',
          {
            'id': 'bad',
            // neps inválido no tumba el parseo
            'neps': null,
            'telar': '2',
          },
          {
            // mapa incompleto pero recuperable
            'telar': '3',
            'neps': '7.5',
          },
        ],
      });

      expect(report.id, 'rep1');
      expect(report.records.length, greaterThanOrEqualTo(2));
      expect(report.records.first.id, 'ok');
    });

    test('tryFromJson devuelve null si falta id usable', () {
      expect(SavedReport.tryFromJson({'name': 'x', 'records': []}), isNull);
    });

    test('informe antiguo sin createdByUid es parseable', () {
      final report = SavedReport.tryFromJson({
        'id': 'legacy',
        'name': 'Viejo',
        'createdAt': '2025-01-01T00:00:00.000',
        'records': [
          {'telar': '9', 'neps': 1},
        ],
      });
      expect(report, isNotNull);
      expect(report!.createdByUid, isNull);
    });
  });

  group('AnalyticsRecordsSource', () {
    test('no duplica el mismo id entre vivos e informes', () {
      final live = [
        NepRecord(id: 'r1', telar: '1', neps: 5, loteTrama: 'L', tela: 'T'),
      ];
      final reports = [
        SavedReport(
          id: 'rep',
          name: 'H',
          createdAt: DateTime(2026, 1, 1),
          records: [
            NepRecord(
                id: 'r1', telar: '1', neps: 99, loteTrama: 'L', tela: 'T'),
            NepRecord(id: 'r2', telar: '2', neps: 3, loteTrama: 'L', tela: 'T'),
          ],
        ),
      ];

      final source = buildAnalyticsRecordsSource(
        liveRecords: live,
        savedReports: reports,
      );

      expect(source.records.length, 2);
      expect(source.records.firstWhere((r) => r.id == 'r1').neps, 5);
      expect(source.isPartial, isFalse);
    });

    test('describe marca resultados parciales', () {
      final source = buildAnalyticsRecordsSource(
        liveRecords: [
          NepRecord(id: 'a', telar: '1', neps: 1, loteTrama: 'L', tela: 'T'),
        ],
        savedReports: const [],
        isPartial: true,
        partialMessage: 'error nube',
      );
      expect(source.describe(), contains('Resultados parciales'));
      expect(source.describe(), contains('error nube'));
    });
  });
}

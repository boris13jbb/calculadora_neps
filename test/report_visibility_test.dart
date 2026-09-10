import 'package:calculadora_neps/core/permissions/report_visibility.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:flutter_test/flutter_test.dart';

SavedReport _report({required String id, String? createdByUid}) {
  return SavedReport(
    id: id,
    name: 'Informe $id',
    createdAt: DateTime(2026, 1, 1),
    records: [NepRecord(telar: '1', neps: 1)],
    createdByUid: createdByUid,
  );
}

void main() {
  test('cuenta sin manageReports no ve informes ajenos ni legacy', () {
    final reports = [
      _report(id: 'a', createdByUid: 'uid-a'),
      _report(id: 'b', createdByUid: 'uid-b'),
      _report(id: 'legacy'),
    ];

    final visible = filterVisibleReports(
      reports,
      viewerUid: 'uid-a',
      canViewTeamReports: false,
    );

    expect(visible.map((r) => r.id), ['a']);
  });

  test('manageReports ve archivo de equipo completo', () {
    final reports = [
      _report(id: 'a', createdByUid: 'uid-a'),
      _report(id: 'b', createdByUid: 'uid-b'),
    ];

    final visible = filterVisibleReports(
      reports,
      viewerUid: 'uid-a',
      canViewTeamReports: true,
    );

    expect(visible.length, 2);
  });
}

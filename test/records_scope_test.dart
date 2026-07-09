import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/domain/records_scope.dart';
import 'package:flutter_test/flutter_test.dart';

NepRecord _record(String id, {double neps = 10}) {
  return NepRecord(
    id: id,
    telar: id,
    neps: neps,
    tela: 'TELA',
    createdAt: DateTime(2026, 1, int.parse(id)),
  );
}

void main() {
  test('RecordsScope aplica filtros en visible', () {
    final scope = RecordsScope();
    scope.items = [
      NepRecord(telar: '1', neps: 10, tela: 'A'),
      NepRecord(telar: '2', neps: 80, tela: 'B'),
    ];
    scope.filters.tela = 'A';

    expect(scope.visible, hasLength(1));
    expect(scope.visible.first.telar, '1');
  });

  test('RecordsScope mergePageResult conserva registros locales', () {
    final scope = RecordsScope();
    scope.items = [
      _record('1'),
      _record('2'),
      _record('3'),
    ];

    scope.mergePageResult([
      _record('4'),
      _record('2', neps: 99),
    ], hasMore: false);

    expect(scope.items, hasLength(4));
    expect(scope.items.firstWhere((r) => r.id == '2').neps, 99);
    expect(scope.items.any((r) => r.id == '1'), isTrue);
    expect(scope.items.any((r) => r.id == '3'), isTrue);
    expect(scope.items.any((r) => r.id == '4'), isTrue);
  });
}

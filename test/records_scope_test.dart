import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/domain/records_scope.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

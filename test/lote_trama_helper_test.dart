import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/utils/lote_trama_helper.dart';

void main() {
  test('divide lote completo en base y sufijo', () {
    final parts = LoteTramaHelper.split('63E264H10A');
    expect(parts.prefix, '63E264');
    expect(parts.suffix, 'H10A');
    expect(parts.full, '63E264H10A');
  });

  test('arma lote con base personalizada', () {
    final full = LoteTramaHelper.buildFull(prefix: '63E274', suffix: 'H10A');
    expect(full, '63E274H10A');
  });

  test('normaliza sufijo quitando la base conocida', () {
    expect(
      LoteTramaHelper.normalizeSuffix('63E264H15F', knownPrefix: '63E264'),
      'H15F',
    );
  });
}

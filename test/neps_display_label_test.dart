import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/models/neps_classification.dart';
import 'package:calculadora_neps/models/nep_record.dart';

void main() {
  group('presentacion centralizada displayLabel', () {
    test('categorias muestran texto visible oficial', () {
      expect(NepsClassification.ok.displayLabel, 'OK');
      expect(NepsClassification.mencion.displayLabel, 'Mención');
      expect(
        NepsClassification.critico.displayLabel,
        'Crítico — Realizar Ajuste',
      );
      expect(NepsClassification.segundaCalidad.displayLabel, '2da Calidad');
    });

    test('estadoAlerta usa displayLabel y no label corto de critico', () {
      final ok = NepRecord(telar: '1', neps: 18, tela: 'T', loteTrama: 'L');
      final mencion =
          NepRecord(telar: '1', neps: 19, tela: 'T', loteTrama: 'L');
      final critico =
          NepRecord(telar: '1', neps: 46, tela: 'T', loteTrama: 'L');
      final segunda =
          NepRecord(telar: '1', neps: 55, tela: 'T', loteTrama: 'L');

      expect(ok.estadoAlerta, 'OK');
      expect(mencion.estadoAlerta, 'Mención');
      expect(critico.estadoAlerta, 'Crítico — Realizar Ajuste');
      expect(segunda.estadoAlerta, '2da Calidad');
      expect(critico.estadoAlerta, isNot('Crítico'));
    });
  });
}

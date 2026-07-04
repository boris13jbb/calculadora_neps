import 'dart:typed_data';

import 'package:calculadora_neps/core/errors/app_exception.dart';
import 'package:calculadora_neps/services/fabric_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FabricCatalogService', () {
    test('importFromBytes lanza ImportException con Excel inválido', () {
      expect(
        () => FabricCatalogService().importFromBytes(
          Uint8List.fromList([0, 1, 2, 3]),
        ),
        throwsA(isA<ImportException>()),
      );
    });

    test('mergeFabrics elimina duplicados sin distinguir mayúsculas', () {
      final merged = FabricCatalogService().mergeFabrics(
        ['Denim', 'Algodón'],
        ['denim', 'Lino'],
      );
      expect(merged, ['Algodón', 'Denim', 'Lino']);
    });
  });
}

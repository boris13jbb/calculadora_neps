import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calculadora_neps/services/lote_trama_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('carga lotes por defecto cuando no hay datos guardados', () async {
    final service = LoteTramaCatalogService();
    final catalog = await service.loadCatalog();

    expect(catalog, contains('63E264H10A'));
    expect(catalog, contains('63E0266H7G'));
    expect(catalog.length, LoteTramaCatalogService.defaultCatalog.length);
  });

  test('normaliza y evita duplicados al guardar', () async {
    final service = LoteTramaCatalogService();
    await service.saveCatalog(['63e264h10a', '63E264H10A', ' 63E266H15A ']);

    final catalog = await service.loadCatalog();
    expect(catalog, ['63E264H10A', '63E266H15A']);
  });
}

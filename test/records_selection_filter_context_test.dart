import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/providers/domain/records_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FILTER — recordsSelectionContextVersion', () {
    test('FILTER-1 onFiltersChanged incrementa context version', () {
      final scope = RecordsScope();
      final before = scope.recordsSelectionContextVersion;
      final panelBefore = scope.filterPanelKey;

      scope.filters.telar = '7';
      scope.onFiltersChanged();

      expect(
        scope.recordsSelectionContextVersion,
        greaterThan(before),
        reason: 'cualquier cambio real de filtro debe invalidar selección',
      );
      // Raíz B1: filterPanelKey puede no cambiar en onFiltersChanged.
      expect(scope.filterPanelKey, panelBefore);
    });

    test('FILTER-2 clearFilters incrementa context version', () {
      final scope = RecordsScope();
      scope.filters.telar = '1';
      final before = scope.recordsSelectionContextVersion;

      scope.clearFilters();

      expect(scope.recordsSelectionContextVersion, greaterThan(before));
    });

    test('FILTER-3 applyNavigationFilters incrementa context version', () {
      final scope = RecordsScope();
      final before = scope.recordsSelectionContextVersion;

      scope.applyNavigationFilters(telar: '3', quickRange: DateQuickRange.hoy);

      expect(scope.recordsSelectionContextVersion, greaterThan(before));
    });

    test('FILTER-1b onFiltersChanged no depende solo de filterPanelKey', () {
      final scope = RecordsScope();
      final panelBefore = scope.filterPanelKey;
      final ctxBefore = scope.recordsSelectionContextVersion;

      scope.filters.tela = 'Denim';
      scope.onFiltersChanged();

      // Con el bug: filterPanelKey no cambia en onFiltersChanged.
      // Con el fix: recordsSelectionContextVersion SÍ debe cambiar.
      expect(scope.recordsSelectionContextVersion, greaterThan(ctxBefore));
      // Documenta la raíz: filterPanelKey puede quedarse igual.
      expect(
        scope.filterPanelKey == panelBefore ||
            scope.recordsSelectionContextVersion > ctxBefore,
        isTrue,
      );
    });
  });
}

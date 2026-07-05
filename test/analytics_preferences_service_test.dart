import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calculadora_neps/models/analytics_period.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/services/analytics_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnalyticsPreferencesService', () {
    test('guarda y restaura periodo y filtros', () async {
      final service = AnalyticsPreferencesService();
      final filters = RecordFilters()
        ..telar = '12'
        ..turno = 'A'
        ..quickRange = DateQuickRange.esteMes;

      await service.save(period: AnalyticsPeriod.week, filters: filters);
      final loaded = await service.load();

      expect(loaded, isNotNull);
      expect(loaded!.period, AnalyticsPeriod.week);
      expect(loaded.filters.telar, '12');
      expect(loaded.filters.turno, 'A');
      expect(loaded.filters.quickRange, DateQuickRange.esteMes);
    });

    test('clear elimina preferencias', () async {
      final service = AnalyticsPreferencesService();
      await service.save(
        period: AnalyticsPeriod.day,
        filters: RecordFilters()..telar = '1',
      );
      await service.clear();
      expect(await service.load(), isNull);
    });
  });
}

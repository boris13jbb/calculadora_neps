import 'dart:async';

import 'package:calculadora_neps/models/analytics_period.dart';
import 'package:calculadora_neps/utils/analytics_reload_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula el patrón de AnalyticsScreen: lee el período vigente al iniciar cada
/// hidratación y, si cambió durante el await, marca pendiente sin aplicar.
class _AnalyticsLoadSimulator {
  _AnalyticsLoadSimulator();

  final LatestWinsReloadGate gate = LatestWinsReloadGate();
  AnalyticsPeriod period = AnalyticsPeriod.month;
  final List<AnalyticsPeriod> applied = [];
  final List<AnalyticsPeriod> started = [];
  int concurrentLoads = 0;
  int maxConcurrentLoads = 0;
  Completer<void>? block;
  bool disposed = false;

  Future<void> requestLoad() {
    if (gate.isBusy) {
      gate.markPending();
      return Future<void>.value();
    }
    return gate.run(_hydrateOnce);
  }

  Future<void> _hydrateOnce() async {
    if (disposed) return;

    final periodAtStart = period;
    started.add(periodAtStart);

    concurrentLoads++;
    if (concurrentLoads > maxConcurrentLoads) {
      maxConcurrentLoads = concurrentLoads;
    }

    final gateCompleter = block;
    if (gateCompleter != null) {
      await gateCompleter.future;
    } else {
      await Future<void>.value();
    }

    concurrentLoads--;
    if (disposed) return;

    if (period != periodAtStart) {
      gate.markPending();
      return;
    }

    applied.add(periodAtStart);
    gate.clearPending();
  }
}

void main() {
  group('LatestWinsReloadGate / carrera de período', () {
    test('Caso 1: carga inicial sin preferencias aplica Mes', () async {
      final sim = _AnalyticsLoadSimulator();
      await sim.requestLoad();
      expect(sim.applied, [AnalyticsPeriod.month]);
      expect(sim.maxConcurrentLoads, 1);
    });

    test('Caso 2: Mes en curso + prefs Año → estado final Año', () async {
      final sim = _AnalyticsLoadSimulator();
      sim.block = Completer<void>();

      final first = sim.requestLoad(); // inicia Mes
      expect(sim.started, [AnalyticsPeriod.month]);

      sim.period = AnalyticsPeriod.year;
      await sim.requestLoad(); // pendiente (busy)

      sim.block!.complete();
      await first;

      expect(sim.maxConcurrentLoads, 1);
      expect(sim.applied, [AnalyticsPeriod.year]);
      expect(sim.started, [AnalyticsPeriod.month, AnalyticsPeriod.year]);
    });

    test('Caso 3: Mes en curso + prefs Semana → estado final Semana', () async {
      final sim = _AnalyticsLoadSimulator();
      sim.block = Completer<void>();

      final first = sim.requestLoad();
      sim.period = AnalyticsPeriod.week;
      await sim.requestLoad();

      sim.block!.complete();
      await first;

      expect(sim.applied, [AnalyticsPeriod.week]);
      expect(sim.maxConcurrentLoads, 1);
    });

    test('Caso 4: Mes→Año→Semana→Mes en curso → final Mes', () async {
      final sim = _AnalyticsLoadSimulator();
      sim.block = Completer<void>();

      final first = sim.requestLoad(); // Mes
      sim.period = AnalyticsPeriod.year;
      await sim.requestLoad();
      sim.period = AnalyticsPeriod.week;
      await sim.requestLoad();
      sim.period = AnalyticsPeriod.month;
      await sim.requestLoad();

      sim.block!.complete();
      await first;

      expect(sim.maxConcurrentLoads, 1);
      expect(sim.applied, [AnalyticsPeriod.month]);
      expect(sim.started, [AnalyticsPeriod.month]);
    });

    test('Caso 5: Mes+Mes no loop infinito ni cargas extras', () async {
      final sim = _AnalyticsLoadSimulator();
      sim.block = Completer<void>();

      final first = sim.requestLoad();
      await sim.requestLoad(); // mismo período mientras busy
      await sim.requestLoad();

      sim.block!.complete();
      await first;

      expect(sim.applied, [AnalyticsPeriod.month]);
      expect(sim.started, [AnalyticsPeriod.month]);
      expect(sim.maxConcurrentLoads, 1);
      expect(sim.gate.isBusy, isFalse);
      expect(sim.gate.hasPending, isFalse);
    });

    test('Caso 6: dispose durante carga no aplica ni relanza', () async {
      final sim = _AnalyticsLoadSimulator();
      sim.block = Completer<void>();

      final first = sim.requestLoad();
      sim.disposed = true;
      sim.period = AnalyticsPeriod.year;
      await sim.requestLoad();

      sim.block!.complete();
      await first;

      expect(sim.applied, isEmpty);
      expect(sim.gate.isBusy, isFalse);
    });

    test('Caso 7: cambio manual Mes→Año tras idle aplica Año', () async {
      final sim = _AnalyticsLoadSimulator();
      await sim.requestLoad();
      expect(sim.applied, [AnalyticsPeriod.month]);

      sim.period = AnalyticsPeriod.year;
      await sim.requestLoad();

      expect(sim.applied, [AnalyticsPeriod.month, AnalyticsPeriod.year]);
      expect(sim.maxConcurrentLoads, 1);
    });
  });
}

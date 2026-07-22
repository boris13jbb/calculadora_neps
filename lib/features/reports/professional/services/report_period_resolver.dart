import '../models/report_period_preset.dart';

/// Resuelve presets de periodo a rangos de fecha concretos.
class ReportPeriodResolver {
  const ReportPeriodResolver();

  ReportDateRange resolve(
    ReportPeriodPreset preset, {
    DateTime? customFrom,
    DateTime? customTo,
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (preset == ReportPeriodPreset.todos) {
      return ReportDateRange(
        start: null,
        end: null,
        preset: preset,
        label: preset.label,
      );
    }

    if (preset == ReportPeriodPreset.rangoPersonalizado) {
      if (customFrom == null || customTo == null) {
        return ReportDateRange(
          start: null,
          end: null,
          preset: preset,
          label: 'Rango personalizado (sin definir)',
        );
      }
      final start = DateTime(
        customFrom.year,
        customFrom.month,
        customFrom.day,
      );
      var end = DateTime(
        customTo.year,
        customTo.month,
        customTo.day,
        23,
        59,
        59,
        999,
      );
      // Normalizar si el usuario invirtió las fechas.
      if (start.isAfter(DateTime(end.year, end.month, end.day))) {
        final swappedStart = DateTime(end.year, end.month, end.day);
        end = DateTime(start.year, start.month, start.day, 23, 59, 59, 999);
        return ReportDateRange(
          start: swappedStart,
          end: end,
          preset: preset,
        );
      }
      return ReportDateRange(
        start: start,
        end: end,
        preset: preset,
      );
    }

    final (start, end) = _rangeForPreset(preset, today);
    return ReportDateRange(
      start: start,
      end: end,
      preset: preset,
    );
  }

  /// Periodo anterior equivalente al preset dado.
  ReportDateRange? previousPeriod(
    ReportPeriodPreset preset, {
    DateTime? reference,
  }) {
    final current = resolve(preset, reference: reference);
    if (current.isAll || current.start == null || current.end == null) {
      return null;
    }

    return switch (preset) {
      ReportPeriodPreset.hoy =>
        resolve(ReportPeriodPreset.ayer, reference: reference),
      ReportPeriodPreset.ayer => () {
          final day = current.start!.subtract(const Duration(days: 1));
          return ReportDateRange(
            start: day,
            end: DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
            preset: ReportPeriodPreset.ayer,
            label: 'Antes de ayer',
          );
        }(),
      ReportPeriodPreset.estaSemana =>
        resolve(ReportPeriodPreset.semanaAnterior, reference: reference),
      ReportPeriodPreset.semanaAnterior => () {
          final start = current.start!.subtract(const Duration(days: 7));
          final end = current.end!.subtract(const Duration(days: 7));
          return ReportDateRange(start: start, end: end, preset: preset);
        }(),
      ReportPeriodPreset.esteMes =>
        resolve(ReportPeriodPreset.mesAnterior, reference: reference),
      ReportPeriodPreset.mesAnterior => () {
          final prevMonth = DateTime(
            current.start!.year,
            current.start!.month - 1,
            1,
          );
          final end = DateTime(
            prevMonth.year,
            prevMonth.month + 1,
            0,
            23,
            59,
            59,
            999,
          );
          return ReportDateRange(
            start: prevMonth,
            end: end,
            preset: ReportPeriodPreset.mesAnterior,
          );
        }(),
      ReportPeriodPreset.esteTrimestre =>
        resolve(ReportPeriodPreset.trimestreAnterior, reference: reference),
      ReportPeriodPreset.trimestreAnterior => () {
          final q = _quarterStart(current.start!);
          final prevQ = DateTime(q.year, q.month - 3, 1);
          final end = DateTime(prevQ.year, prevQ.month + 3, 0, 23, 59, 59, 999);
          return ReportDateRange(start: prevQ, end: end, preset: preset);
        }(),
      ReportPeriodPreset.esteAno =>
        resolve(ReportPeriodPreset.anoAnterior, reference: reference),
      ReportPeriodPreset.anoAnterior => () {
          final year = current.start!.year - 1;
          return ReportDateRange(
            start: DateTime(year, 1, 1),
            end: DateTime(year, 12, 31, 23, 59, 59, 999),
            preset: ReportPeriodPreset.anoAnterior,
          );
        }(),
      _ => null,
    };
  }

  (DateTime, DateTime) _rangeForPreset(
    ReportPeriodPreset preset,
    DateTime today,
  ) {
    return switch (preset) {
      ReportPeriodPreset.hoy => (
          today,
          DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
        ),
      ReportPeriodPreset.ayer => () {
          final day = today.subtract(const Duration(days: 1));
          return (
            day,
            DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
          );
        }(),
      ReportPeriodPreset.estaSemana => () {
          final start = _weekStart(today);
          return (
            start,
            DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
          );
        }(),
      ReportPeriodPreset.semanaAnterior => () {
          final thisWeekStart = _weekStart(today);
          final start = thisWeekStart.subtract(const Duration(days: 7));
          final end = thisWeekStart.subtract(const Duration(milliseconds: 1));
          return (start, end);
        }(),
      ReportPeriodPreset.esteMes => (
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
        ),
      ReportPeriodPreset.mesAnterior => () {
          final start = DateTime(today.year, today.month - 1, 1);
          final end = DateTime(today.year, today.month, 0, 23, 59, 59, 999);
          return (start, end);
        }(),
      ReportPeriodPreset.esteTrimestre => () {
          final start = _quarterStart(today);
          return (
            start,
            DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
          );
        }(),
      ReportPeriodPreset.trimestreAnterior => () {
          final thisQ = _quarterStart(today);
          final start = DateTime(thisQ.year, thisQ.month - 3, 1);
          final end = thisQ.subtract(const Duration(milliseconds: 1));
          return (start, end);
        }(),
      ReportPeriodPreset.esteAno => (
          DateTime(today.year, 1, 1),
          DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
        ),
      ReportPeriodPreset.anoAnterior => (
          DateTime(today.year - 1, 1, 1),
          DateTime(today.year - 1, 12, 31, 23, 59, 59, 999),
        ),
      _ => (
          today,
          DateTime(today.year, today.month, today.day, 23, 59, 59, 999)
        ),
    };
  }

  DateTime _weekStart(DateTime day) =>
      day.subtract(Duration(days: day.weekday - 1));

  DateTime _quarterStart(DateTime day) {
    final qMonth = ((day.month - 1) ~/ 3) * 3 + 1;
    return DateTime(day.year, qMonth, 1);
  }
}

const reportPeriodResolver = ReportPeriodResolver();

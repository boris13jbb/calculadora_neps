import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/report_actions.dart';
import 'package:calculadora_neps/models/export_column.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/utils/today_capture_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';

NepRecord _rec({
  required String id,
  required DateTime createdAt,
  required String uid,
  String telar = '1',
  String tela = 'Denim',
  String lote = 'L1',
  double neps = 10,
}) {
  return NepRecord(
    id: id,
    telar: telar,
    tela: tela,
    loteTrama: lote,
    neps: neps,
    createdAt: createdAt,
    createdByUid: uid,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 11, 16, 0);
  final todayMorning = DateTime(2026, 9, 11, 9, 0);
  final todayNoon = DateTime(2026, 9, 11, 11, 0);
  final todayEvening = DateTime(2026, 9, 11, 15, 0);
  final yesterday = DateTime(2026, 9, 10, 18, 0);

  group('Filtro todayCaptureRecords', () {
    test('A) latestTodayCaptureRecord es el más reciente de hoy', () {
      final records = [
        _rec(id: 'r1', createdAt: todayMorning, uid: 'A'),
        _rec(id: 'r2', createdAt: todayNoon, uid: 'A'),
        _rec(id: 'r3', createdAt: todayEvening, uid: 'A'),
      ];
      final latest = resolveLatestTodayCaptureRecord(
        records: records,
        authUid: 'A',
        now: now,
      );
      expect(latest?.id, 'r3');
    });

    test('E) ayer excluido de la lista', () {
      final records = [
        _rec(id: 'r0', createdAt: yesterday, uid: 'A'),
        _rec(id: 'r1', createdAt: todayMorning, uid: 'A'),
        _rec(id: 'r2', createdAt: todayNoon, uid: 'A'),
      ];
      final today = filterTodayCaptureRecords(
        records: records,
        authUid: 'A',
        now: now,
      );
      expect(today.map((r) => r.id), ['r2', 'r1']);
    });

    test('F) otro usuario excluido', () {
      final records = [
        _rec(id: 'r1', createdAt: todayMorning, uid: 'A'),
        _rec(id: 'r2', createdAt: todayNoon, uid: 'A'),
        _rec(id: 'r3', createdAt: todayEvening, uid: 'B'),
      ];
      final today = filterTodayCaptureRecords(
        records: records,
        authUid: 'A',
        now: now,
      );
      expect(today.map((r) => r.id), ['r2', 'r1']);
    });

    test('ownership ambiguo excluido', () {
      final ambiguous = NepRecord(
        id: 'rx',
        telar: '9',
        neps: 1,
        createdAt: todayNoon,
        createdByUid: null,
      );
      final today = filterTodayCaptureRecords(
        records: [ambiguous, _rec(id: 'r1', createdAt: todayMorning, uid: 'A')],
        authUid: 'A',
        now: now,
      );
      expect(today.map((r) => r.id), ['r1']);
    });
  });

  group('Selección en diálogo Compartir', () {
    List<NepRecord> eligible() => [
          _rec(
            id: 'r3',
            createdAt: todayEvening,
            uid: 'A',
            telar: '23',
            tela: 'Denim X',
            lote: '1203',
            neps: 14,
          ),
          _rec(
            id: 'r2',
            createdAt: todayNoon,
            uid: 'A',
            telar: '18',
            tela: 'Denim Y',
            lote: '1198',
            neps: 9,
          ),
          _rec(
            id: 'r1',
            createdAt: todayMorning,
            uid: 'A',
            telar: '12',
            tela: 'Denim X',
            lote: '1180',
            neps: 7,
          ),
        ];

    Future<void> pumpDialog(
      WidgetTester tester, {
      String? initialSelectedId,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: ShareCaptureRecordsDialog(
              eligibleRecords: eligible(),
              initialSelectedId: initialSelectedId,
              initialColumns: ExportColumn.defaultSelection(),
              initialStyle: PdfReportStyle.completo,
              formatDateTime: (d) {
                String two(int n) => n.toString().padLeft(2, '0');
                return '${two(d.day)}/${two(d.month)}/${d.year} '
                    '${two(d.hour)}:${two(d.minute)}';
              },
              formatNeps: (n) => n.toStringAsFixed(0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('A) solo el último registro seleccionado por defecto',
        (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r3');
      expect(find.text('Compartir 1 registro'), findsOneWidget);

      final state = tester.state<ShareCaptureRecordsDialogState>(
        find.byType(ShareCaptureRecordsDialog),
      );
      expect(state.selectedRecords.map((r) => r.id), ['r3']);
    });

    testWidgets('C) selección manual r1+r3 sin r2', (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r3');
      final state = tester.state<ShareCaptureRecordsDialogState>(
        find.byType(ShareCaptureRecordsDialog),
      );

      // Marcar r1 (tercera fila en lista ordenada desc: r3, r2, r1)
      final tiles = find.byType(CheckboxListTile);
      await tester.tap(tiles.at(2));
      await tester.pump();

      expect(state.selectedRecords.map((r) => r.id).toSet(), {'r3', 'r1'});
      expect(find.text('Compartir 2 registros'), findsOneWidget);
    });

    testWidgets('D) seleccionar todos los de hoy', (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r3');
      await tester.tap(find.text('Seleccionar todos los de hoy'));
      await tester.pump();

      final state = tester.state<ShareCaptureRecordsDialogState>(
        find.byType(ShareCaptureRecordsDialog),
      );
      expect(state.selectedCount, 3);
      expect(find.text('Compartir 3 registros'), findsOneWidget);
    });

    testWidgets('G) compartir desde fila inicia solo con ese registro',
        (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r1');
      final state = tester.state<ShareCaptureRecordsDialogState>(
        find.byType(ShareCaptureRecordsDialog),
      );
      expect(state.selectedRecords.map((r) => r.id), ['r1']);
      expect(find.text('Compartir 1 registro'), findsOneWidget);
    });

    testWidgets('H) cero selección deshabilita CSV/Excel/PDF', (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r3');
      await tester.tap(find.text('Limpiar selección'));
      await tester.pump();

      expect(find.text('Seleccione al menos un registro.'), findsOneWidget);

      final csv = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'CSV'),
      );
      final excel = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Excel'),
      );
      final pdf = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'PDF'),
      );
      expect(csv.onPressed, isNull);
      expect(excel.onPressed, isNull);
      expect(pdf.onPressed, isNull);
    });

    testWidgets('B) selección exportable es solo r3', (tester) async {
      await pumpDialog(tester, initialSelectedId: 'r3');
      final state = tester.state<ShareCaptureRecordsDialogState>(
        find.byType(ShareCaptureRecordsDialog),
      );
      expect(state.selectedRecords.map((r) => r.id), ['r3']);
      expect(state.selectedRecords.map((r) => r.id), isNot(contains('r1')));
      expect(state.selectedRecords.map((r) => r.id), isNot(contains('r2')));
    });
  });

  group('Export sourceRecords vs visibleRecords', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('I) sin sourceRecords usa visibleRecords; con sourceRecords exacto',
        () async {
      final state = AppState();
      state.applyAuthProfile(
        AppUser(
          uid: 'A',
          username: 'oper',
          role: AppUserRole.operario,
        ),
      );
      await state.initialize();

      final r1 = _rec(id: 'r1', createdAt: todayMorning, uid: 'A');
      final r2 = _rec(id: 'r2', createdAt: todayNoon, uid: 'A');
      final r3 = _rec(id: 'r3', createdAt: todayEvening, uid: 'A');
      state.records = [r1, r2, r3];

      expect(state.resolveExportRecords(null).map((r) => r.id).toSet(),
          {'r1', 'r2', 'r3'});
      expect(state.resolveExportRecords([r3]).map((r) => r.id), ['r3']);
      expect(
        state.resolveExportRecords([r1, r3]).map((r) => r.id).toSet(),
        {'r1', 'r3'},
      );

      // AppState todayCapture con reloj real: inyectamos vía util.
      final today = filterTodayCaptureRecords(
        records: state.records,
        authUid: 'A',
        now: now,
      );
      expect(today.map((r) => r.id), ['r3', 'r2', 'r1']);

      state.dispose();
    });
  });

  group('SaveCaptureSessionReportDialog', () {
    Future<void> pumpSaveDialog(
      WidgetTester tester, {
      required List<NepRecord> eligible,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: SaveCaptureSessionReportDialog(
              eligibleRecords: eligible,
              initialName: 'Informe prueba',
              style: PdfReportStyle.completo,
              formatDateTime: (d) =>
                  '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute}',
              formatNeps: (n) => n.toStringAsFixed(0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('por defecto selecciona solo el pendiente más reciente',
        (tester) async {
      final records = [
        _rec(id: 'a', createdAt: todayMorning, uid: 'A', telar: '10'),
        _rec(id: 'b', createdAt: todayNoon, uid: 'A', telar: '20'),
        _rec(id: 'c', createdAt: todayEvening, uid: 'A', telar: '30'),
      ];
      await pumpSaveDialog(tester, eligible: records);

      final state = tester.state<SaveCaptureSessionReportDialogState>(
        find.byType(SaveCaptureSessionReportDialog),
      );
      expect(state.selectedCount, 1);
      expect(state.selectedRecords.map((r) => r.id), ['c']);
      expect(find.text('Guardar 1 registro'), findsOneWidget);
    });

    testWidgets('Seleccionar pendientes marca todos los elegibles',
        (tester) async {
      final records = [
        _rec(id: 'a', createdAt: todayMorning, uid: 'A', telar: '10'),
        _rec(id: 'b', createdAt: todayNoon, uid: 'A', telar: '20'),
        _rec(id: 'c', createdAt: todayEvening, uid: 'A', telar: '30'),
      ];
      await pumpSaveDialog(tester, eligible: records);

      final state = tester.state<SaveCaptureSessionReportDialogState>(
        find.byType(SaveCaptureSessionReportDialog),
      );
      state.clearSelection();
      await tester.pump();
      expect(state.selectedCount, 0);

      state.selectPending();
      await tester.pump();
      expect(state.selectedRecords.map((r) => r.id).toSet(), {'a', 'b', 'c'});
      expect(find.text('Guardar 3 registros'), findsOneWidget);
    });
  });
}

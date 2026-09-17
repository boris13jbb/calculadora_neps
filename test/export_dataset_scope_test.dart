import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/export_column.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/record_export_coordinator.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyExportCoordinator extends RecordExportCoordinator {
  _SpyExportCoordinator() : super(exportService: ReportExportService());

  List<NepRecord>? lastCsvRecords;
  List<NepRecord>? lastExcelRecords;
  List<NepRecord>? lastPdfRecords;
  int csvCalls = 0;
  int excelCalls = 0;
  int pdfCalls = 0;

  @override
  Future<void> shareCsv({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
  }) async {
    csvCalls++;
    lastCsvRecords = List<NepRecord>.from(records);
  }

  @override
  Future<void> shareExcel({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
  }) async {
    excelCalls++;
    lastExcelRecords = List<NepRecord>.from(records);
  }

  @override
  Future<void> sharePdf({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
    String? filtersDescription,
  }) async {
    pdfCalls++;
    lastPdfRecords = List<NepRecord>.from(records);
  }
}

NepRecord _rec(String id, {String tela = 'A'}) {
  return NepRecord(
    id: id,
    telar: id,
    neps: 10,
    tela: tela,
    loteTrama: 'L1',
    createdAt: DateTime(2026, 9, 16, 12),
    createdByUid: 'u1',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  Future<({AppState state, _SpyExportCoordinator spy})> ready() async {
    final spy = _SpyExportCoordinator();
    final state = AppState(recordExportCoordinator: spy);
    state.applyAuthProfile(
      AppUser(uid: 'u1', username: 'admin', role: AppUserRole.admin),
    );
    await state.initialize();
    return (state: state, spy: spy);
  }

  group('H2 runExport dataset real', () {
    test('H2-A sourceRecords con datos + visible vacío → export permitido',
        () async {
      final readyPair = await ready();
      final state = readyPair.state;
      final spy = readyPair.spy;
      final r1 = _rec('R1');
      state.records = [r1];
      state.filters.tela = 'NO_MATCH';
      expect(state.visibleRecords, isEmpty);

      await state.exportCsv(sourceRecords: [r1]);

      expect(spy.csvCalls, 1);
      expect(spy.lastCsvRecords?.map((r) => r.id), ['R1']);
      state.dispose();
    });

    test('H2-B sourceRecords vacío → export bloqueado', () async {
      final readyPair = await ready();
      final state = readyPair.state;
      final spy = readyPair.spy;
      state.records = [_rec('R1')];

      await state.exportCsv(sourceRecords: const []);

      expect(spy.csvCalls, 0);
      state.dispose();
    });

    test('H2-C sourceRecords null + visible vacío → bloqueado', () async {
      final readyPair = await ready();
      final state = readyPair.state;
      final spy = readyPair.spy;
      state.records = [_rec('R1')];
      state.filters.tela = 'NO_MATCH';
      expect(state.visibleRecords, isEmpty);

      await state.exportCsv();

      expect(spy.csvCalls, 0);
      state.dispose();
    });

    test('H2-D sourceRecords null + visibles → usa visibleRecords', () async {
      final readyPair = await ready();
      final state = readyPair.state;
      final spy = readyPair.spy;
      final r1 = _rec('R1', tela: 'KEEP');
      final r2 = _rec('R2', tela: 'DROP');
      state.records = [r1, r2];
      state.filters.tela = 'KEEP';
      expect(state.visibleRecords.map((r) => r.id), ['R1']);

      await state.exportExcel();

      expect(spy.excelCalls, 1);
      expect(spy.lastExcelRecords?.map((r) => r.id), ['R1']);
      state.dispose();
    });

    test('H2-E sourceRecords [R2] + visible [R1] → exporta exactamente R2',
        () async {
      final readyPair = await ready();
      final state = readyPair.state;
      final spy = readyPair.spy;
      final r1 = _rec('R1', tela: 'KEEP');
      final r2 = _rec('R2', tela: 'DROP');
      state.records = [r1, r2];
      state.filters.tela = 'KEEP';
      expect(state.visibleRecords.map((r) => r.id), ['R1']);

      await state.exportPdf(sourceRecords: [r2]);

      expect(spy.pdfCalls, 1);
      expect(spy.lastPdfRecords?.map((r) => r.id), ['R2']);
      state.dispose();
    });

    test('runExport directo usa recordsToExport y no visibleRecords', () async {
      final readyPair = await ready();
      final state = readyPair.state;
      state.records = [_rec('R1')];
      state.filters.tela = 'NO_MATCH';
      expect(state.visibleRecords, isEmpty);

      var ran = false;
      await state.runExport(
        recordsToExport: [_rec('RX')],
        action: () async {
          ran = true;
        },
      );
      expect(ran, isTrue);
      state.dispose();
    });
  });
}

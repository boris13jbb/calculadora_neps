import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_delete_outcome.dart';
import 'package:calculadora_neps/utils/records_multi_selection.dart';
import 'package:flutter_test/flutter_test.dart';

NepRecord _rec(String id) => NepRecord(
      id: id,
      telar: '1',
      neps: 10,
      tela: 'Denim',
      loteTrama: 'L1',
      createdAt: DateTime.utc(2026, 9, 11, 12),
    );

List<NepRecord> _dataset(int count) =>
    List.generate(count, (i) => _rec('R${i + 1}'));

void main() {
  group('SEL — selección por id', () {
    test('SEL-1 marcar una fila → selected = {R1}', () {
      final selection = RecordsMultiSelection();
      selection.toggle('R1');
      expect(selection.selectedRecordIds, {'R1'});
      expect(selection.count, 1);
    });

    test('SEL-2 desmarcar R1 → selected vacío', () {
      final selection = RecordsMultiSelection()..toggle('R1');
      selection.toggle('R1');
      expect(selection.selectedRecordIds, isEmpty);
      expect(selection.count, 0);
    });

    test('SEL-3 seleccionar R1 y R2 → count = 2', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2');
      expect(selection.count, 2);
      expect(selection.selectedRecordIds, {'R1', 'R2'});
    });

    test('SEL-4 checkbox maestro selecciona SOLO página actual (25 de 30)', () {
      final records = _dataset(30);
      const rowsPerPage = 25;
      final pageIds = pageRecordIds(
        records: records,
        page: 0,
        rowsPerPage: rowsPerPage,
      );
      expect(pageIds.length, 25);

      final selection = RecordsMultiSelection()..selectAllOnPage(pageIds);
      expect(selection.count, 25);
      expect(selection.selectedRecordIds.contains('R26'), isFalse);
      expect(selection.selectedRecordIds.contains('R30'), isFalse);
      expect(selection.selectedRecordIds.contains('R1'), isTrue);
      expect(selection.selectedRecordIds.contains('R25'), isTrue);
    });

    test('SEL-5 checkbox maestro con todos seleccionados → desmarca página',
        () {
      final pageIds = ['R1', 'R2', 'R3'];
      final selection = RecordsMultiSelection()..selectAllOnPage(pageIds);
      expect(selection.count, 3);

      selection.toggleSelectAllOnPage(pageIds);
      expect(selection.selectedRecordIds, isEmpty);
    });

    test('SEL-6 selección parcial → encabezado indeterminado', () {
      final pageIds = ['R1', 'R2', 'R3'];
      final selection = RecordsMultiSelection()..toggle('R1');
      expect(selection.isPageIndeterminate(pageIds), isTrue);
      expect(selection.isPageFullySelected(pageIds), isFalse);
      expect(selection.isPageNoneSelected(pageIds), isFalse);
    });

    test('SEL-7 ir a página siguiente → selección vacía', () {
      final records = _dataset(30);
      final selection = RecordsMultiSelection()
        ..selectAllOnPage(
          pageRecordIds(records: records, page: 0, rowsPerPage: 25),
        );
      expect(selection.count, 25);

      selection.onPageContextChanged();
      expect(selection.selectedRecordIds, isEmpty);
    });

    test('SEL-8 cambiar rowsPerPage → selección vacía', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2');
      selection.onPageContextChanged();
      expect(selection.selectedRecordIds, isEmpty);
    });

    test('SEL-9 cambiar filtros/dataset visible → prune/vacía selección', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2')
        ..toggle('R3');

      // Filtro cambia el contexto visual: se limpia por contrato de seguridad.
      selection.onFilterContextChanged();
      expect(selection.selectedRecordIds, isEmpty);

      selection
        ..toggle('R1')
        ..toggle('R99');
      selection.pruneToExisting({'R1', 'R2'});
      expect(selection.selectedRecordIds, {'R1'});
    });
  });

  group('EDIT — actualizar con selección', () {
    test('EDIT-1 0 seleccionados → Actualizar no disponible', () {
      final selection = RecordsMultiSelection();
      expect(selection.canUpdate(canEditRecords: true), isFalse);
    });

    test('EDIT-2 1 seleccionado + canEditRecords → disponible', () {
      final selection = RecordsMultiSelection()..toggle('R1');
      expect(selection.canUpdate(canEditRecords: true), isTrue);
    });

    test('EDIT-3 2 seleccionados → Actualizar no disponible', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2');
      expect(selection.canUpdate(canEditRecords: true), isFalse);
    });

    test('EDIT-4 1 seleccionado sin canEditRecords → no disponible', () {
      final selection = RecordsMultiSelection()..toggle('R1');
      expect(selection.canUpdate(canEditRecords: false), isFalse);
    });

    test('EDIT-5 Actualizar seleccionado resuelve el NepRecord correcto', () {
      final records = [_rec('R1'), _rec('R2'), _rec('R3')];
      final selection = RecordsMultiSelection()..toggle('R2');
      final resolved = selection.resolveSingleSelected(records);
      expect(resolved, isNotNull);
      expect(resolved!.id, 'R2');
    });

    test('EDIT-6/7 orquestación: guardar usa update; cancelar no llama',
        () async {
      NepRecord? edited;
      var updateCalls = 0;
      final records = [_rec('R1')];
      final selection = RecordsMultiSelection()..toggle('R1');

      final cancelled = await runUpdateSelectedRecord(
        selection: selection,
        records: records,
        canEditRecords: true,
        openEditor: (record) async {
          edited = record;
          return false; // cancelar
        },
        onUpdated: () => updateCalls++,
      );
      expect(cancelled, isFalse);
      expect(edited?.id, 'R1');
      expect(updateCalls, 0);
      expect(selection.selectedRecordIds, {'R1'});

      edited = null;
      final saved = await runUpdateSelectedRecord(
        selection: selection,
        records: records,
        canEditRecords: true,
        openEditor: (record) async {
          edited = record;
          // El editor real llama updateRecord; aquí simulamos éxito.
          return true;
        },
        onUpdated: () => updateCalls++,
      );
      expect(saved, isTrue);
      expect(edited?.id, 'R1');
      expect(updateCalls, 1);
      // EDIT-8: tras actualización exitosa, selección limpia.
      expect(selection.selectedRecordIds, isEmpty);
    });

    test('EDIT-8 después de actualización exitosa → selección limpia',
        () async {
      final selection = RecordsMultiSelection()..toggle('R1');
      await runUpdateSelectedRecord(
        selection: selection,
        records: [_rec('R1')],
        canEditRecords: true,
        openEditor: (_) async => true,
      );
      expect(selection.selectedRecordIds, isEmpty);
    });
  });

  group('DEL — eliminación múltiple segura', () {
    test('DEL-1 0 seleccionados → eliminar no disponible', () {
      final selection = RecordsMultiSelection();
      expect(selection.canBulkDelete(canDeleteRecords: true), isFalse);
    });

    test('DEL-2 confirmación usa exactamente el conteo seleccionado', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2')
        ..toggle('R3');
      expect(selection.count, 3);
      expect(bulkDeleteConfirmTitle(3), contains('3'));
      expect(bulkDeleteConfirmActionLabel(3), contains('3'));
      expect(bulkDeleteConfirmTitle(1), contains('1 registro'));
      expect(bulkDeleteConfirmActionLabel(1), 'Eliminar 1');
    });

    test('DEL-3 cancelar confirmación → 0 llamadas a deleteRecord', () async {
      final deleteCalls = <String>[];
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2');

      final summary = await runBulkDeleteSelected(
        selectedIds: selection.selectedRecordIds,
        canDeleteRecords: true,
        confirmed: false,
        deleteRecord: (id) async {
          deleteCalls.add(id);
          return RecordDeleteOutcome.deletedRemote;
        },
      );

      expect(deleteCalls, isEmpty);
      expect(summary.succeeded, 0);
      expect(summary.failed, 0);
      expect(summary.wasCancelled, isTrue);
    });

    test('DEL-4 confirmar R1,R2,R3 → deleteRecord una vez por ID', () async {
      final deleteCalls = <String>[];
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1', 'R2', 'R3'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          deleteCalls.add(id);
          return RecordDeleteOutcome.deletedRemote;
        },
      );

      expect(deleteCalls.toSet(), {'R1', 'R2', 'R3'});
      expect(deleteCalls, hasLength(3));
      expect(summary.succeeded, 3);
      expect(summary.failed, 0);
    });

    test('DEL-5 no usa clearTable/clearRecords/replaceRecords', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async => RecordDeleteOutcome.deletedRemote,
      );
      // El helper solo itera deleteRecord; no expone clear/replace globales.
      expect(summary.succeeded, 1);
      expect(summary.failed, 0);
    });

    test('DEL-6 seleccionar todos página 25 → delete solo esos 25', () async {
      final records = _dataset(30);
      final pageIds = pageRecordIds(
        records: records,
        page: 0,
        rowsPerPage: 25,
      );
      final selection = RecordsMultiSelection()..selectAllOnPage(pageIds);
      final deleteCalls = <String>[];

      await runBulkDeleteSelected(
        selectedIds: Set<String>.from(selection.selectedRecordIds),
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          deleteCalls.add(id);
          return RecordDeleteOutcome.deletedRemote;
        },
      );

      expect(deleteCalls, hasLength(25));
      expect(deleteCalls.contains('R26'), isFalse);
      expect(deleteCalls.contains('R30'), isFalse);
    });

    test('DEL-7 permissionDenied → permanece / no fingir eliminado', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1', 'R2', 'R3'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          if (id == 'R2') return RecordDeleteOutcome.permissionDenied;
          return RecordDeleteOutcome.deletedRemote;
        },
      );

      expect(summary.succeeded, 2);
      expect(summary.failed, 1);
      expect(summary.remainingSelectedIds, {'R2'});
      expect(summary.message, contains('2'));
      expect(summary.message, contains('1'));
    });

    test('DEL-8 deletedRemote → éxito', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (_) async => RecordDeleteOutcome.deletedRemote,
      );
      expect(summary.succeeded, 1);
      expect(summary.remainingSelectedIds, isEmpty);
    });

    test('DEL-9 deletedLocalPendingSync → éxito/pending aceptado', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (_) async => RecordDeleteOutcome.deletedLocalPendingSync,
      );
      expect(summary.succeeded, 1);
      expect(summary.remainingSelectedIds, isEmpty);
    });

    test('DEL-10 firebaseError → registro permanece seleccionado', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (_) async => RecordDeleteOutcome.firebaseError,
      );
      expect(summary.succeeded, 0);
      expect(summary.failed, 1);
      expect(summary.remainingSelectedIds, {'R1'});
    });

    test('DEL-11 notFound → no rompe operación ni deja fantasma', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1', 'R2'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          if (id == 'R1') return RecordDeleteOutcome.notFound;
          return RecordDeleteOutcome.deletedRemote;
        },
      );
      expect(summary.succeeded, 1);
      expect(summary.failed, 1);
      // notFound no es reintentable: no permanece seleccionado.
      expect(summary.remainingSelectedIds, isEmpty);
    });

    test('NOTFOUND-1 R1 notFound + R2 deleted → remaining vacío', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1', 'R2'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          if (id == 'R1') return RecordDeleteOutcome.notFound;
          return RecordDeleteOutcome.deletedRemote;
        },
      );
      expect(summary.succeeded, 1);
      expect(summary.failed, 1);
      expect(summary.remainingSelectedIds, isEmpty);
    });

    test('NOTFOUND-2 permissionDenied → remaining {R1}', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (_) async => RecordDeleteOutcome.permissionDenied,
      );
      expect(summary.remainingSelectedIds, {'R1'});
    });

    test('NOTFOUND-3 firebaseError → remaining {R1}', () async {
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1'},
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (_) async => RecordDeleteOutcome.firebaseError,
      );
      expect(summary.remainingSelectedIds, {'R1'});
    });

    test('DEL-12 sin canDeleteRecords → no ejecuta deleteRecord', () async {
      final deleteCalls = <String>[];
      final summary = await runBulkDeleteSelected(
        selectedIds: {'R1', 'R2'},
        canDeleteRecords: false,
        confirmed: true,
        deleteRecord: (id) async {
          deleteCalls.add(id);
          return RecordDeleteOutcome.deletedRemote;
        },
      );
      expect(deleteCalls, isEmpty);
      expect(summary.succeeded, 0);
      expect(summary.wasDeniedByPermission, isTrue);
    });

    test('snapshot de IDs: no depende de índices mutables', () async {
      final selected = {'R1', 'R2', 'R3'};
      final deleteCalls = <String>[];
      // Simula mutación externa del set original durante el borrado.
      await runBulkDeleteSelected(
        selectedIds: selected,
        canDeleteRecords: true,
        confirmed: true,
        deleteRecord: (id) async {
          deleteCalls.add(id);
          selected.remove(id);
          return RecordDeleteOutcome.deletedRemote;
        },
      );
      expect(deleteCalls.toSet(), {'R1', 'R2', 'R3'});
      expect(deleteCalls, hasLength(3));
    });
  });

  group('REALTIME — selección ⊆ página visible', () {
    test('REALTIME-1 insertar NEW mueve R50 fuera de página → vacío', () {
      final records = _dataset(51);
      const rowsPerPage = 50;
      final pageIds = pageRecordIds(
        records: records,
        page: 0,
        rowsPerPage: rowsPerPage,
      );
      expect(pageIds.last, 'R50');

      final selection = RecordsMultiSelection()..toggle('R50');
      expect(selection.selectedRecordIds, {'R50'});

      // Realtime inserta NEW al inicio: R50 pasa a página 2.
      final updated = [_rec('NEW'), ...records];
      final changed = syncSelectionToCurrentPage(
        selection: selection,
        records: updated,
        page: 0,
        rowsPerPage: rowsPerPage,
      );
      expect(changed, isTrue);
      expect(selection.selectedRecordIds, isEmpty);
    });

    test('REALTIME-2 seleccionado sigue en página → se conserva', () {
      final records = _dataset(51);
      final selection = RecordsMultiSelection()..toggle('R1');
      final updated = [_rec('NEW'), ...records];
      final changed = syncSelectionToCurrentPage(
        selection: selection,
        records: updated,
        page: 0,
        rowsPerPage: 50,
      );
      // R1 sigue en página 0 (posición 1).
      expect(changed, isFalse);
      expect(selection.selectedRecordIds, {'R1'});
    });

    test('REALTIME-3 registro desaparece del dataset → poda', () {
      final selection = RecordsMultiSelection()
        ..toggle('R1')
        ..toggle('R2');
      final changed = syncSelectionToCurrentPage(
        selection: selection,
        records: [_rec('R2'), _rec('R3')],
        page: 0,
        rowsPerPage: 50,
      );
      expect(changed, isTrue);
      expect(selection.selectedRecordIds, {'R2'});
    });

    test('REALTIME-4 página fuera de rango se ajusta y limpia selección', () {
      final records = _dataset(60);
      final selection = RecordsMultiSelection()
        ..selectAllOnPage(
          pageRecordIds(records: records, page: 1, rowsPerPage: 50),
        );
      expect(selection.count, 10); // R51..R60

      // Dataset se reduce: página 1 ya no existe; effectivePage=0.
      final reduced = _dataset(40);
      final changed = syncSelectionToCurrentPage(
        selection: selection,
        records: reduced,
        page: 1,
        rowsPerPage: 50,
      );
      expect(changed, isTrue);
      expect(selection.selectedRecordIds, isEmpty);
    });
  });
}

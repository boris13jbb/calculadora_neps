import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/records_table.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_delete_outcome.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id) => NepRecord(
      id: id,
      telar: id.replaceAll('R', ''),
      neps: 10,
      tela: 'Denim',
      loteTrama: 'L1',
      createdAt: DateTime.utc(2026, 9, 11, 12),
      createdByUid: 'u1',
    );

Future<void> _pumpTable(
  WidgetTester tester, {
  required AppState state,
  required List<NepRecord> records,
  required Future<RecordDeleteOutcome> Function(String id) onDelete,
  Future<bool> Function(NepRecord record)? onEdit,
  double width = 1280,
  double height = 800,
  int selectionResetToken = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: RecordsTable(
            appState: state,
            records: records,
            onDelete: onDelete,
            onEdit: onEdit,
            selectionResetToken: selectionResetToken,
            userContextKey: state.authUid ?? '',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  testWidgets('UI desktop: checkbox, toolbar update/delete y limpiar',
      (tester) async {
    final state = AppState()
      ..applyAuthProfile(
        AppUser(uid: 'u1', username: 'admin', role: AppUserRole.admin),
      );
    expect(state.canDeleteRecords, isTrue);
    expect(state.canEditRecords, isTrue);

    NepRecord? edited;
    final deleted = <String>[];
    final records = List.generate(3, (i) => _rec('R${i + 1}'));

    await _pumpTable(
      tester,
      state: state,
      records: records,
      onDelete: (id) async {
        deleted.add(id);
        return RecordDeleteOutcome.deletedRemote;
      },
      onEdit: (record) async {
        edited = record;
        return true;
      },
    );

    expect(find.byType(Checkbox), findsWidgets);

    // Marca primera fila (checkbox de datos, no el maestro).
    final rowCheckboxes = find.byType(Checkbox);
    await tester.tap(rowCheckboxes.at(1));
    await tester.pumpAndSettle();

    expect(find.text('1 seleccionado'), findsOneWidget);
    expect(find.text('Actualizar registro'), findsOneWidget);
    expect(find.text('Eliminar seleccionado'), findsOneWidget);

    await tester.tap(find.text('Actualizar registro'));
    await tester.pumpAndSettle();
    expect(edited?.id, 'R1');
    expect(find.text('1 seleccionado'), findsNothing);

    await tester.tap(rowCheckboxes.at(1));
    await tester.pumpAndSettle();
    await tester.tap(rowCheckboxes.at(2));
    await tester.pumpAndSettle();
    expect(find.text('2 seleccionados'), findsOneWidget);
    expect(find.text('Actualizar registro'), findsNothing);

    await tester.tap(find.text('Eliminar seleccionados'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eliminar 2 registros'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);

    await tester.tap(find.text('Limpiar selección'));
    await tester.pumpAndSettle();
    expect(find.text('2 seleccionados'), findsNothing);

    state.dispose();
  });

  testWidgets('UI móvil: selección usable sin romper editar individual',
      (tester) async {
    final state = AppState()
      ..applyAuthProfile(
        AppUser(uid: 'u1', username: 'admin', role: AppUserRole.admin),
      );

    var editCalls = 0;
    await _pumpTable(
      tester,
      state: state,
      records: [_rec('R1'), _rec('R2')],
      width: 360,
      height: 700,
      onDelete: (_) async => RecordDeleteOutcome.deletedRemote,
      onEdit: (_) async {
        editCalls++;
        return false;
      },
    );

    expect(find.byType(Checkbox), findsWidgets);
    expect(find.textContaining('Seleccionar visibles'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar').first);
    await tester.pumpAndSettle();
    expect(editCalls, 1);

    state.dispose();
  });

  testWidgets('sin permisos de edit/delete no muestra checkboxes',
      (tester) async {
    // operario base: capture+view, sin edit/delete en producción típica;
    // forzamos rol sin ambos permisos.
    RoleCatalog.instance.upsert(
      RoleCatalog.instance.get('operario')!.copyWith(
        permissions: {Permission.viewRecords, Permission.captureRecords},
      ),
    );
    final state = AppState()
      ..applyAuthProfile(
        AppUser(uid: 'op', username: 'op', role: AppUserRole.operario),
      );
    expect(state.canDeleteRecords, isFalse);
    expect(state.canEditRecords, isFalse);

    await _pumpTable(
      tester,
      state: state,
      records: [_rec('R1')],
      onDelete: (_) async => RecordDeleteOutcome.deletedRemote,
      onEdit: null,
    );

    expect(find.byType(Checkbox), findsNothing);
    state.dispose();
  });
}

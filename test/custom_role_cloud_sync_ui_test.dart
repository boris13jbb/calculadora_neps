import 'dart:io';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/record_visibility.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/records_table.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/role_definition.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/cloud_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RoleDefinition _auditorRole() {
  return RoleDefinition(
    code: 'auditor_prueba',
    name: 'Auditor Prueba',
    description: 'Rol temporal de prueba',
    permissions: {
      Permission.viewDashboard,
      Permission.viewRecords,
      Permission.viewWorkspaceRecords,
    },
    isActive: true,
    isSystem: false,
    isAssignable: true,
    sortOrder: 60,
  );
}

AppUser _auditorUser() {
  return AppUser(
    uid: 'qa-auditor-uid',
    username: '373255',
    displayName: 'jbb',
    roleCode: 'auditor_prueba',
    isActive: true,
  );
}

NepRecord _sampleRecord() {
  return NepRecord(
    id: 'r1',
    telar: '1',
    tela: 'T1',
    loteTrama: 'L1',
    neps: 10,
    createdAt: DateTime.utc(2026, 9, 11),
  );
}

void main() {
  setUp(() {
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll([
      ...RoleCatalog.baseRoles,
      _auditorRole(),
    ]);
    RoleCatalog.instance.markAuthorizationReady();
  });

  test('A) bootstrap autenticado no escribe workspace', () async {
    final source =
        await File('lib/services/cloud_sync_service.dart').readAsString();
    expect(source.contains('await _workspace.set('), isFalse);
    expect(CloudSyncService.touchesWorkspaceOnBootstrap, isFalse);
  });

  test(
      'B) rol personalizado con viewRecords+viewWorkspaceRecords sync sin manageSettings',
      () {
    expect(
      RoleCatalog.instance
          .hasPermission('auditor_prueba', Permission.manageSettings),
      isFalse,
    );
    expect(
      RoleCatalog.instance
          .hasPermission('auditor_prueba', Permission.viewRecords),
      isTrue,
    );
    expect(
      RoleCatalog.instance
          .hasPermission('auditor_prueba', Permission.viewWorkspaceRecords),
      isTrue,
    );
    expect(CloudSyncService.touchesWorkspaceOnBootstrap, isFalse);
  });

  testWidgets('C/D) sin captureRecords no aparece Importar ni Ir a Captura',
      (tester) async {
    final appState = AppState()..applyAuthProfile(_auditorUser());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: RecordsTable(
            appState: appState,
            records: const [],
            onDelete: (_) async {},
            onEdit: null,
            onGoToCapture: null,
            onGoToImport: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar datos'), findsNothing);
    expect(find.text('Ir a Captura'), findsNothing);
    expect(find.text('Importar'), findsNothing);
  });

  testWidgets('E) sin editRecords no aparece Editar', (tester) async {
    final appState = AppState()..applyAuthProfile(_auditorUser());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: RecordsTable(
              appState: appState,
              records: [_sampleRecord()],
              onDelete: (_) async {},
              onEdit: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Editar'), findsNothing);
  });

  test('F) auditor_prueba muestra Auditor Prueba y no Operario', () {
    final user = _auditorUser();
    expect(user.roleCode, 'auditor_prueba');
    expect(user.roleLabel, 'Auditor Prueba');
    expect(user.roleLabel, isNot('Operario'));
    // Enum legacy: no usar role.label en UI para roles personalizados.
    expect(user.role.label, 'Operario');
  });

  test('G) con viewWorkspaceRecords usa colección workspace', () {
    expect(canViewWorkspaceRecordsForCode('auditor_prueba'), isTrue);
  });

  test('H) sin viewWorkspaceRecords usa colección propia', () {
    RoleCatalog.instance.upsert(
      RoleDefinition(
        code: 'auditor_local',
        name: 'Auditor Local',
        permissions: {
          Permission.viewDashboard,
          Permission.viewRecords,
        },
        isActive: true,
        isSystem: false,
        isAssignable: true,
        sortOrder: 61,
      ),
    );
    expect(canViewWorkspaceRecordsForCode('auditor_local'), isFalse);
    expect(canViewWorkspaceRecordsForCode('operario'), isFalse);
  });
}

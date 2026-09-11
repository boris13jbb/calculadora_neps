import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/features/users/roles_screen.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/providers/auth_provider.dart';
import 'package:calculadora_neps/repositories/role_collection_gateway.dart';
import 'package:calculadora_neps/repositories/role_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late MemoryRoleCollectionGateway gateway;
  late RoleRepository repository;

  setUp(() {
    RoleCatalog.instance.resetAuthorization();
    gateway = MemoryRoleCollectionGateway();
    repository = RoleRepository(
      roles: gateway,
      countUsersWithRole: (_) async => 0,
    );
  });

  test('A) listRoles en colección vacía no escribe', () async {
    final roles = await repository.listRoles();

    expect(roles, isEmpty);
    expect(gateway.documents, isEmpty);
    expect(gateway.writeCount, 0);
  });

  test('B) autorización super_admin sin documento usa fallback y no escribe',
      () async {
    await repository.ensureAuthorizationForRole('super_admin');

    expect(RoleCatalog.instance.authorizationReady, isTrue);
    expect(
      RoleCatalog.instance.hasPermission('super_admin', Permission.manageUsers),
      isTrue,
    );
    expect(gateway.writeCount, 0);
    expect(gateway.documents, isEmpty);
  });

  test('C) autorización admin sin documento no escribe roles', () async {
    await repository.ensureAuthorizationForRole('admin');

    expect(RoleCatalog.instance.authorizationReady, isTrue);
    expect(
      RoleCatalog.instance.hasPermission('admin', Permission.viewDashboard),
      isTrue,
    );
    expect(gateway.writeCount, 0);
  });

  test('D) rol custom desconocido se niega y no escribe', () async {
    await repository.ensureAuthorizationForRole('auditor_prueba');

    expect(RoleCatalog.instance.authorizationReady, isTrue);
    expect(
      RoleCatalog.instance
          .hasPermission('auditor_prueba', Permission.viewRecords),
      isFalse,
    );
    expect(gateway.writeCount, 0);
    expect(gateway.documents, isEmpty);
  });

  test('E) ensureBaseRoles explícito crea exactamente 5 documentos', () async {
    await repository.ensureBaseRoles();

    expect(gateway.documents.keys.toSet(), RoleCatalog.systemRoleCodes);
    expect(gateway.writeCount, 5);
  });

  test('F) ensureBaseRoles es idempotente', () async {
    await repository.ensureBaseRoles();
    await repository.ensureBaseRoles();

    expect(gateway.documents.length, 5);
    expect(gateway.writeCount, 5);
  });

  testWidgets('G) montar RolesScreen con colección vacía no escribe',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_rolesApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Inicializar roles base'), findsOneWidget);
    expect(gateway.writeCount, 0);
    expect(gateway.documents, isEmpty);
  });

  testWidgets('H) la inicialización solo ocurre tras confirmar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_rolesApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inicializar roles base'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(gateway.writeCount, 0);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(gateway.writeCount, 0);

    await tester.tap(find.text('Inicializar roles base'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicializar'));
    await tester.pumpAndSettle();

    expect(gateway.documents.length, 5);
    expect(gateway.writeCount, 5);
    expect(find.text('Inicializar roles base'), findsNothing);
  });
}

Widget _rolesApp(RoleRepository repository) {
  RoleCatalog.instance.markAuthorizationReady();
  final auth = AuthProvider(roleRepository: repository)
    ..profile = AppUser(
      uid: 'sa',
      username: 'super',
      roleCode: 'super_admin',
    )
    ..status = AuthStatus.authenticated
    ..authorizationReady = true;

  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.build(),
      home: RolesScreen(repository: repository),
    ),
  );
}

class MemoryRoleCollectionGateway implements RoleCollectionGateway {
  final Map<String, Map<String, dynamic>> documents = {};
  int writeCount = 0;

  @override
  Future<Map<String, dynamic>?> getDocument(String id) async {
    final data = documents[id];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments() async {
    return documents.entries.map((entry) {
      return {
        ...entry.value,
        'code': entry.value['code'] ?? entry.key,
      };
    }).toList();
  }

  @override
  Future<void> setDocument(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    writeCount++;
    documents[id] = merge
        ? {...?documents[id], ...data, 'code': data['code'] ?? id}
        : {...data, 'code': data['code'] ?? id};
  }
}

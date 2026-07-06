import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../permissions/permission.dart';
import 'permission_gate.dart';

/// Envuelve una pantalla de navegación con el [Permission] declarado en [AppNavigation].
class NavPermissionGate extends StatelessWidget {
  const NavPermissionGate({
    super.key,
    required this.navId,
    required this.child,
    this.fallback,
  });

  final AppNavId navId;
  final Widget child;
  final Widget? fallback;

  static Permission permissionFor(AppNavId id) {
    return AppNavigation.all.firstWhere((item) => item.id == id).permission;
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: permissionFor(navId),
      fallback: fallback,
      child: child,
    );
  }
}

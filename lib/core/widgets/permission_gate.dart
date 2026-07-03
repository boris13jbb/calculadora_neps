import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../permissions/permission.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';
import '../../providers/auth_provider.dart';

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.hasPermission(permission)) return child;

    return fallback ??
        const EmptyState(
          icon: Icons.lock_outline,
          title: 'Acceso denegado',
          message:
              'No tiene permisos para acceder a esta sección. Contacte al administrador.',
          iconColor: AppColors.danger,
        );
  }
}

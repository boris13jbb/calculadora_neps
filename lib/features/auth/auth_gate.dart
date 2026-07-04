import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loading_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
      case AuthStatus.loadingProfile:
        return const AppLoadingView(message: 'Verificando sesión...');
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.deactivated:
        return Scaffold(
          body: Center(
            child: EmptyState(
              icon: Icons.block,
              title: 'Usuario desactivado',
              message: auth.errorMessage ?? 'Contacte al super administrador.',
              iconColor: AppColors.danger,
              actions: [
                EmptyStateAction(
                  label: 'Volver al login',
                  icon: Icons.login,
                  onPressed: auth.signOut,
                ),
              ],
            ),
          ),
        );
      case AuthStatus.accessDenied:
        return Scaffold(
          body: Center(
            child: EmptyState(
              icon: Icons.block,
              title: 'Acceso denegado',
              message: auth.errorMessage ??
                  'No tiene permiso para acceder al sistema.',
              iconColor: AppColors.danger,
              actions: [
                EmptyStateAction(
                  label: 'Volver al login',
                  icon: Icons.login,
                  onPressed: auth.signOut,
                ),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        return child;
    }
  }
}

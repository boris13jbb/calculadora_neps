import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/errors/error_handler.dart';
import '../../core/theme/app_theme.dart';

import '../../core/widgets/app_input_decoration.dart';

import '../../providers/auth_provider.dart';

import '../../utils/username_auth_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  bool _isLoading = false;

  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;

      _successMessage = null;
    });

    try {
      await context
          .read<AuthProvider>()
          .sendPasswordReset(_emailController.text);

      if (mounted) {
        setState(() {
          _successMessage =
              'Se envió un correo con instrucciones para restablecer la contraseña.';
        });
      }
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'sendPasswordReset');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo enviar el correo: ${ErrorHandler.userMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Solo disponible para super administradores con '
                      'correo real. Los usuarios normales deben solicitar '
                      'reset de contraseña al super administrador.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: appInputDecoration('admin@empresa.com')
                          .copyWith(labelText: 'Correo del super admin'),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) return 'Ingrese su correo.';

                        if (!UsernameAuthHelper.isEmail(email)) {
                          return 'Correo no válido.';
                        }

                        return null;
                      },
                    ),
                    if (_successMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar enlace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

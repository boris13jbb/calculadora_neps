import 'package:calculadora_neps/core/errors/app_exception.dart';
import 'package:calculadora_neps/core/errors/error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorHandler', () {
    test('userMessage devuelve mensaje de AppException', () {
      const error = ImportException('Archivo inválido');
      expect(ErrorHandler.userMessage(error), 'Archivo inválido');
    });

    test('userMessage mapea FirebaseAuthException conocida', () {
      final error = FirebaseAuthException(code: 'wrong-password');
      expect(
        ErrorHandler.userMessage(error),
        'Usuario o contraseña incorrectos.',
      );
    });

    test('userMessage devuelve mensaje de UserAdminException', () {
      const error = UserAdminException('El usuario ya existe.');
      expect(ErrorHandler.userMessage(error), 'El usuario ya existe.');
    });

    test('userMessage mapea StateError', () {
      expect(
        ErrorHandler.userMessage(StateError('Usuario no autenticado.')),
        'Usuario no autenticado.',
      );
    });

    test('userMessage oculta detalles técnicos genéricos', () {
      expect(
        ErrorHandler.userMessage(
            Exception('SocketException: failed host lookup')),
        contains('conexión'),
      );
    });
  });
}

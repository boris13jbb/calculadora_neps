import 'package:flutter/services.dart';

/// Solo digitos enteros (telar, etc.).
final List<TextInputFormatter> digitsOnlyInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
];

/// Nombre de tela manual: letras, numeros y espacios.
final List<TextInputFormatter> fabricNameInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
];

/// Numeros con un solo separador decimal (punto o coma).
class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^[\d.,]*$').hasMatch(text)) return oldValue;

    final normalized = text.replaceAll(',', '.');
    if ('.'.allMatches(normalized).length > 1) return oldValue;

    return newValue;
  }
}

final List<TextInputFormatter> decimalNumberInputFormatters = [
  DecimalTextInputFormatter(),
];

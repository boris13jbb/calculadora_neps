import 'package:flutter_test/flutter_test.dart';
import 'package:calculadora_neps/utils/numeric_input_formatters.dart';

void main() {
  group('DecimalTextInputFormatter', () {
    final formatter = DecimalTextInputFormatter();

    TextEditingValue format(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(text: newText),
      );
    }

    test('acepta enteros', () {
      expect(format('', '53').text, '53');
    });

    test('acepta decimal con punto', () {
      expect(format('12', '12.5').text, '12.5');
    });

    test('rechaza letras', () {
      expect(format('', 'abc').text, '');
    });

    test('rechaza mas de un separador decimal', () {
      expect(format('12.3', '12.3.4').text, '12.3');
    });
  });
}

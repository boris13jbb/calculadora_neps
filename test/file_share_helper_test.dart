import 'package:calculadora_neps/utils/file_share_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileShareHelper.resolveShareText', () {
    const caption = 'Informes VICUNHA - 1 informe (completo)';

    test('Caso 1: sin archivos conserva el texto (nativo y web)', () {
      expect(
        FileShareHelper.resolveShareText(
          hasFiles: false,
          text: caption,
          isWebOverride: false,
        ),
        caption,
      );
      expect(
        FileShareHelper.resolveShareText(
          hasFiles: false,
          text: caption,
          isWebOverride: true,
        ),
        caption,
      );
      expect(
        FileShareHelper.resolveShareText(hasFiles: false, text: null),
        isNull,
      );
    });

    test('Caso 2: un archivo en nativo omite el texto', () {
      expect(
        FileShareHelper.resolveShareText(
          hasFiles: true,
          text: 'Reporte CSV de Neps',
          isWebOverride: false,
        ),
        isNull,
      );
    });

    test('Caso 3: múltiples archivos en nativo omiten el texto', () {
      expect(
        FileShareHelper.resolveShareText(
          hasFiles: true,
          text: caption,
          isWebOverride: false,
        ),
        isNull,
      );
    });

    test('con archivos en Web conserva el texto', () {
      expect(
        FileShareHelper.resolveShareText(
          hasFiles: true,
          text: caption,
          isWebOverride: true,
        ),
        caption,
      );
    });

    test('MIME constants usados al compartir archivos', () {
      expect(
        FileShareHelper.excelMimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });
  });
}

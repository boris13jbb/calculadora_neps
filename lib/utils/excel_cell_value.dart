import 'package:excel/excel.dart' as xls;

/// Convierte un número a celda Excel evitando ceros decimales artificiales.
///
/// Enteros (p. ej. `32` o `32.0`) usan [xls.IntCellValue] para que Excel
/// muestre `32` y no `32.0`. Solo las fracciones reales usan double.
xls.CellValue excelNumericCellValue(num value) {
  final asDouble = value.toDouble();
  if (asDouble.isNaN || asDouble.isInfinite) {
    return xls.TextCellValue(value.toString());
  }
  if (asDouble == asDouble.roundToDouble()) {
    return xls.IntCellValue(asDouble.round());
  }
  return xls.DoubleCellValue(asDouble);
}

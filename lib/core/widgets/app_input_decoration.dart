import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Densidad visual de campos de captura sin alterar otras pantallas.
enum AppInputSize {
  /// Estilo por defecto (bordes redondeados amplios).
  standard,

  /// Compacto para paneles densos existentes.
  compact,

  /// Ultra compacto (legacy; evitar en captura).
  ultraCompact,

  /// Campos de sesión (Tela, Lote): altura cómoda ~60.
  comfortable,

  /// Telar / Neps: altura prominente ~72 y tipografía grande.
  prominent,
}

InputDecoration appInputDecoration(
  String hint, {
  bool compact = false,
  bool ultraCompact = false,
  AppInputSize? size,
}) {
  final resolved = size ??
      (ultraCompact
          ? AppInputSize.ultraCompact
          : (compact ? AppInputSize.compact : AppInputSize.standard));

  switch (resolved) {
    case AppInputSize.comfortable:
      return _captureDecoration(
        hint: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        radius: 12,
        borderWidth: 1.5,
      );
    case AppInputSize.prominent:
      return _captureDecoration(
        hint: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        radius: 12,
        borderWidth: 1.5,
      );
    case AppInputSize.ultraCompact:
      return _legacyDecoration(
        hint: hint,
        horizontal: 8,
        vertical: 6,
        radius: 8,
        borderWidth: 1.5,
        dense: true,
      );
    case AppInputSize.compact:
      return _legacyDecoration(
        hint: hint,
        horizontal: 12,
        vertical: 10,
        radius: 10,
        borderWidth: 2,
        dense: true,
      );
    case AppInputSize.standard:
      return _legacyDecoration(
        hint: hint,
        horizontal: 16,
        vertical: 14,
        radius: 40,
        borderWidth: 2,
        dense: false,
      );
  }
}

InputDecoration _captureDecoration({
  required String hint,
  required EdgeInsetsGeometry contentPadding,
  required double radius,
  required double borderWidth,
}) {
  final border = BorderRadius.circular(radius);
  return InputDecoration(
    hintText: hint,
    isDense: false,
    filled: true,
    fillColor: Colors.white,
    contentPadding: contentPadding,
    enabledBorder: OutlineInputBorder(
      borderRadius: border,
      borderSide: BorderSide(color: AppColors.border, width: borderWidth),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: border,
      borderSide:
          BorderSide(color: AppColors.accentDark, width: borderWidth + 0.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: border,
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: border,
      borderSide: const BorderSide(color: AppColors.danger, width: 2),
    ),
  );
}

InputDecoration _legacyDecoration({
  required String hint,
  required double horizontal,
  required double vertical,
  required double radius,
  required double borderWidth,
  required bool dense,
}) {
  return InputDecoration(
    hintText: hint,
    isDense: dense,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: const Color(0xFFCFC29C),
        width: borderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: AppColors.accentDark,
        width: borderWidth,
      ),
    ),
  );
}

/// Altura mínima recomendada por [AppInputSize] (flexible; no recorta errores).
double appInputMinHeight(AppInputSize size) {
  switch (size) {
    case AppInputSize.prominent:
      return 72;
    case AppInputSize.comfortable:
      return 60;
    case AppInputSize.standard:
      return 48;
    case AppInputSize.compact:
      return 40;
    case AppInputSize.ultraCompact:
      return 36;
  }
}

/// Texto oscuro legible para valor seleccionado en dropdowns.
TextStyle appDropdownTextStyle({
  bool ultraCompact = false,
  bool compact = false,
  AppInputSize? size,
}) {
  if (size == AppInputSize.comfortable || size == AppInputSize.prominent) {
    final fontSize = size == AppInputSize.prominent ? 24.0 : 18.0;
    return TextStyle(
      fontSize: fontSize,
      color: AppColors.textDark,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }

  return TextStyle(
    fontSize: ultraCompact ? 13 : (compact ? 14 : 15),
    color: AppColors.textDark,
    fontWeight: FontWeight.w600,
  );
}

/// Texto oscuro para cada opción del menú desplegable.
TextStyle get appDropdownItemTextStyle => const TextStyle(
      color: AppColors.textDark,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

Widget appDropdownItemText(
  String label, {
  bool compact = false,
  bool wrap = false,
}) {
  return Text(
    label,
    overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
    softWrap: wrap,
    style: appDropdownItemTextStyle.copyWith(
      fontSize: compact ? 13 : 14,
    ),
  );
}

/// Etiqueta persistente de campo de captura (no depende solo del placeholder).
class CaptureFieldLabel extends StatelessWidget {
  const CaptureFieldLabel(
    this.text, {
    super.key,
    this.prominent = false,
  });

  final String text;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: prominent ? 16 : 15.5,
          color: AppColors.textDark,
          height: 1.2,
        ),
      ),
    );
  }
}

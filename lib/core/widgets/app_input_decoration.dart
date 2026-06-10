import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

InputDecoration appInputDecoration(
  String hint, {
  bool compact = false,
  bool ultraCompact = false,
}) {
  final dense = compact || ultraCompact;

  return InputDecoration(
    hintText: hint,
    isDense: dense,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: ultraCompact ? 8 : (compact ? 12 : 16),
      vertical: ultraCompact ? 6 : (compact ? 10 : 14),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(ultraCompact ? 8 : (compact ? 10 : 40)),
      borderSide: BorderSide(
        color: const Color(0xFFCFC29C),
        width: ultraCompact ? 1.5 : 2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(ultraCompact ? 8 : (compact ? 10 : 40)),
      borderSide: BorderSide(
        color: AppColors.accentDark,
        width: ultraCompact ? 1.5 : 2,
      ),
    ),
  );
}

/// Texto oscuro legible para valor seleccionado en dropdowns.
TextStyle appDropdownTextStyle(
    {bool ultraCompact = false, bool compact = false}) {
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

Widget appDropdownItemText(String label, {bool compact = false}) {
  return Text(
    label,
    overflow: TextOverflow.ellipsis,
    style: appDropdownItemTextStyle.copyWith(
      fontSize: compact ? 13 : 14,
    ),
  );
}

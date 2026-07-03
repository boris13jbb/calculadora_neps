import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Estilos compartidos para ListTile con contraste visible de splash/ripple.
abstract final class AppListTileStyles {
  static const Color splashColor = Color(0x2EC5A059);
  static const Color hoverColor = Color(0x1AC5A059);
  static const Color focusColor = Color(0x24C5A059);

  static Color sheetTileColor({required bool selected}) {
    return selected ? AppColors.formulaBg : AppColors.surfaceAlt;
  }
}

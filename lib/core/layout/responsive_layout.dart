import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Teléfono o vista compacta (incluye móvil en horizontal).
///
/// Usa el lado corto de la pantalla para no activar layouts de tablet/escritorio
/// solo porque el ancho en landscape supera [AppBreakpoints.tablet].
bool isPhoneLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide < AppBreakpoints.tablet;
}

/// Escritorio real: ancho amplio y lado corto suficiente (no móvil horizontal).
bool isDesktopLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= AppBreakpoints.desktop &&
      size.shortestSide >= AppBreakpoints.phone;
}

/// Altura reducida (landscape en móvil, teclado, ventanas bajas).
bool hasCompactHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 520;

double screenSpacing(BuildContext context,
        {double normal = 16, double dense = 8}) =>
    isPhoneLayout(context) ? dense : normal;

EdgeInsets sectionPadding(BuildContext context) =>
    isPhoneLayout(context) ? const EdgeInsets.all(8) : const EdgeInsets.all(14);

double sectionRadius(BuildContext context) => isPhoneLayout(context) ? 10 : 14;

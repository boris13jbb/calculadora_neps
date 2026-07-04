import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../layout/responsive_layout.dart';
import '../theme/app_styles.dart';
import '../theme/app_theme.dart';
import 'app_breadcrumb.dart';
import 'app_top_bar.dart';

/// Contenedor estándar de una pantalla.
///
/// Aporta el chrome común (barra superior profesional [AppTopBar]) y un área de
/// contenido que aprovecha todo el ancho disponible. Por defecto el contenido
/// ocupa el 100% del ancho (útil para tablas, dashboards y monitores anchos);
/// las pantallas centradas en formularios pueden limitar con [maxContentWidth].
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.breadcrumb,
    this.actions,
    this.fillViewport = false,
    this.maxContentWidth = double.infinity,
    this.compactPadding = false,
    this.denseOnPhone = false,
    this.useContentCard = false,
  });

  final String title;
  final String? subtitle;
  final List<String>? breadcrumb;
  final Widget child;
  final List<Widget>? actions;
  final bool fillViewport;

  /// Ancho máximo del contenido. `double.infinity` = ancho completo.
  final double maxContentWidth;
  final bool compactPadding;
  final bool denseOnPhone;
  final bool useContentCard;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = isPhoneLayout(context);
    final dense = denseOnPhone && isPhone;

    final hGutter = dense ? 10.0 : (compactPadding ? 16.0 : 24.0);
    final vGutter = dense ? 10.0 : (compactPadding ? 14.0 : 18.0);
    final effectiveH = width >= AppBreakpoints.wide ? hGutter + 4 : hGutter;

    Widget pageBody = child;
    if (useContentCard) {
      pageBody = Container(
        width: double.infinity,
        height: fillViewport ? double.infinity : null,
        padding: EdgeInsets.all(dense ? 10 : 16),
        decoration: AppDecorations.card(),
        child: child,
      );
    }

    // Solo se centra/limita cuando hay un ancho máximo finito.
    final Widget constrained = maxContentWidth.isFinite
        ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: pageBody,
            ),
          )
        : pageBody;

    final contentPadding = EdgeInsets.fromLTRB(
      effectiveH,
      vGutter,
      effectiveH,
      vGutter,
    );

    return Container(
      color: AppColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTopBar(
            title: title,
            subtitle: subtitle,
            actions: actions,
          ),
          if (breadcrumb != null)
            Padding(
              padding: EdgeInsets.fromLTRB(effectiveH, 10, effectiveH, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppBreadcrumb(segments: breadcrumb!),
              ),
            ),
          Expanded(
            child: fillViewport
                ? Padding(padding: contentPadding, child: constrained)
                : SingleChildScrollView(
                    padding: contentPadding,
                    child: constrained,
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/list_tile_styles.dart';

/// [ListTile] envuelto en [Material] propio para que el splash/ink no quede
/// oculto por contenedores con color (Container, DecoratedBox, etc.).
class AppMaterialListTile extends StatelessWidget {
  const AppMaterialListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.dense = false,
    this.visualDensity,
    this.contentPadding,
    this.minVerticalPadding,
    this.backgroundColor,
    this.shape,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool dense;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? contentPadding;
  final double? minVerticalPadding;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ??
        AppListTileStyles.sheetTileColor(selected: selected);
    return Material(
      color: bg,
      shape: shape,
      child: onTap == null
          ? listTile
          : InkWell(
              onTap: onTap,
              splashColor: AppListTileStyles.splashColor,
              hoverColor: AppListTileStyles.hoverColor,
              focusColor: AppListTileStyles.focusColor,
              child: listTile,
            ),
    );
  }

  Widget get listTile => ListTile(
        dense: dense,
        selected: selected,
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        visualDensity: visualDensity,
        contentPadding: contentPadding,
        minVerticalPadding: minVerticalPadding,
      );
}

/// [SwitchListTile] con [Material] propio (mismo problema de ink/background).
class AppMaterialSwitchListTile extends StatelessWidget {
  const AppMaterialSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    this.backgroundColor,
    this.activeThumbColor,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.surfaceAlt,
      child: SwitchListTile(
        contentPadding: contentPadding,
        title: title,
        subtitle: subtitle,
        value: value,
        activeThumbColor: activeThumbColor,
        onChanged: onChanged,
      ),
    );
  }
}

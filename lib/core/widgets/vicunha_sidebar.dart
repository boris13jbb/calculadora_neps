import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Destino de navegación del sidebar.
class VicunhaNavDestination {
  const VicunhaNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Contador opcional (p. ej. alertas críticas) mostrado como badge.
  final int badgeCount;
}

/// Sidebar de navegación profesional para escritorio/web.
///
/// Estructura clara: marca arriba, navegación con estado activo visible y pie
/// con usuario/rol y cierre de sesión. Soporta modo colapsado (solo iconos).
class VicunhaSidebar extends StatelessWidget {
  const VicunhaSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.extended = true,
    this.onToggleExtended,
    this.userName,
    this.userRole,
    this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<VicunhaNavDestination> destinations;
  final bool extended;
  final VoidCallback? onToggleExtended;
  final String? userName;
  final String? userRole;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 244.0 : 76.0;

    return Container(
      width: width,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrand(),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: destinations.length,
              itemBuilder: (context, index) => _buildItem(index),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: EdgeInsets.fromLTRB(extended ? 16 : 12, 18, extended ? 12 : 12, 14),
      child: Row(
        mainAxisAlignment:
            extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          if (extended) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VICUNHA',
                    style: TextStyle(
                      color: AppColors.headerText,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'jeansidentity',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggleExtended != null)
              IconButton(
                tooltip: 'Colapsar menú',
                onPressed: onToggleExtended,
                iconSize: 20,
                color: AppColors.headerMuted,
                icon: const Icon(Icons.chevron_left),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = destinations[index];
    final selected = index == selectedIndex;
    final foreground =
        selected ? AppColors.sidebar : AppColors.headerMuted;

    final iconWidget = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 20,
      color: foreground,
    );

    final icon = item.badgeCount > 0
        ? Badge(
            label: Text('${item.badgeCount}'),
            backgroundColor: AppColors.statusCritical,
            child: iconWidget,
          )
        : iconWidget;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Tooltip(
            message: extended ? '' : item.label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? 14 : 0,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  icon,
                  if (extended) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 13.5,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final name = (userName == null || userName!.isEmpty) ? 'Usuario' : userName!;
    final role = userRole ?? '';
    final initials = _initials(name);

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          children: [
            if (onToggleExtended != null)
              IconButton(
                tooltip: 'Expandir menú',
                onPressed: onToggleExtended,
                iconSize: 20,
                color: AppColors.headerMuted,
                icon: const Icon(Icons.chevron_right),
              ),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withValues(alpha: 0.18),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            if (onSignOut != null) ...[
              const SizedBox(height: 8),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: onSignOut,
                iconSize: 20,
                color: AppColors.headerMuted,
                icon: const Icon(Icons.logout),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.headerText,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (role.isNotEmpty)
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.headerMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (onSignOut != null)
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onSignOut,
                  iconSize: 20,
                  color: AppColors.headerMuted,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sistema VICUNHA v1.0.0',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.headerMuted.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VicunhaSidebar extends StatelessWidget {
  const VicunhaSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.extended = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<VicunhaNavDestination> destinations;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 220.0 : 72.0;

    return Container(
      width: width,
      color: AppColors.sidebar,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final item = destinations[index];
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(10),
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
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              size: 20,
                              color: selected
                                  ? AppColors.sidebar
                                  : const Color(0xFFCFD8C5),
                            ),
                            if (extended) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: selected
                                        ? AppColors.sidebar
                                        : const Color(0xFFCFD8C5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: extended
                ? Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: AppColors.muted.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sistema VICUNHA v1.0.0',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: Color(0xFF8A9A9E),
                  ),
          ),
        ],
      ),
    );
  }
}

class VicunhaNavDestination {
  const VicunhaNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

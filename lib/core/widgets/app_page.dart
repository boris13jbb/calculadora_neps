import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_styles.dart';
import '../theme/app_theme.dart';
import 'app_breadcrumb.dart';

class VicunhaBrandBar extends StatelessWidget {
  const VicunhaBrandBar({
    super.key,
    this.subtitle,
    this.minimal = false,
    this.showUserActions = true,
  });

  final String? subtitle;
  final bool minimal;
  final bool showUserActions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppBreakpoints.phone || minimal;

    if (minimal) {
      return Container(
        width: double.infinity,
        color: AppColors.header,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: const Text(
          'VICUNHA · jeansidentity',
          style: TextStyle(
            color: AppColors.headerText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.header,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 24,
        compact ? 12 : 16,
        compact ? 14 : 24,
        compact ? 10 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: compact ? 8 : 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'VICUNHA',
                      style: TextStyle(
                        color: AppColors.headerText,
                        fontSize: compact ? 22 : 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        'jeansidentity',
                        style: TextStyle(
                          color: AppColors.header,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.headerMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showUserActions && !compact) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_none,
                    color: AppColors.headerText,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accent,
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.header,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'jeansidentity',
                    style: TextStyle(
                      color: AppColors.headerText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.headerMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.breadcrumb,
    this.actions,
    this.fillViewport = false,
    this.maxContentWidth = 1200,
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
  final double maxContentWidth;
  final bool compactPadding;
  final bool denseOnPhone;
  final bool useContentCard;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;
    final dense = denseOnPhone && isPhone;

    final outerPadding = dense ? 6.0 : (compactPadding ? 12.0 : 20.0);
    final innerPadding = dense ? 8.0 : (compactPadding ? 14.0 : 20.0);

    Widget pageBody = child;
    if (useContentCard) {
      pageBody = Container(
        width: double.infinity,
        height: fillViewport ? double.infinity : null,
        padding: EdgeInsets.all(innerPadding),
        decoration: AppDecorations.card(),
        child: child,
      );
    }

    final centeredContent = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: pageBody,
      ),
    );

    return Container(
      color: AppColors.backgroundGradientStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dense)
            const VicunhaBrandBar(minimal: true, showUserActions: false)
          else
            VicunhaBrandBar(subtitle: subtitle),
          if (!dense)
            Container(
              color: AppColors.backgroundGradientStart,
              padding: EdgeInsets.fromLTRB(
                compactPadding ? 16 : 24,
                16,
                compactPadding ? 16 : 24,
                8,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackHeader =
                      constraints.maxWidth < AppBreakpoints.phone;

                  final titleColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: compactPadding ? 20 : 24,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (subtitle != null && compactPadding) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  );

                  final breadcrumbWidget = breadcrumb != null
                      ? AppBreadcrumb(segments: breadcrumb!)
                      : null;

                  final actionsWidget = actions == null || actions!.isEmpty
                      ? null
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: actions!,
                        );

                  if (stackHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (breadcrumbWidget != null) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: breadcrumbWidget,
                          ),
                          const SizedBox(height: 8),
                        ],
                        titleColumn,
                        if (actionsWidget != null) ...[
                          const SizedBox(height: 10),
                          actionsWidget,
                        ],
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleColumn),
                          if (breadcrumbWidget != null) breadcrumbWidget,
                        ],
                      ),
                      if (actionsWidget != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionsWidget,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          if (dense)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: fillViewport
                ? Padding(
                    padding: EdgeInsets.all(outerPadding),
                    child: centeredContent,
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(outerPadding),
                    child: centeredContent,
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';

class VicunhaBrandBar extends StatelessWidget {
  const VicunhaBrandBar({super.key, this.subtitle, this.minimal = false});

  final String? subtitle;
  final bool minimal;

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
            color: Color(0xFFF7EAC5),
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
        compact ? 14 : 20,
        compact ? 14 : 18,
        compact ? 14 : 20,
        compact ? 10 : 14,
      ),
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
                  color: const Color(0xFFF7EAC5),
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontFamily: 'serif',
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
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: const Color(0xFFCFD8C5),
                fontSize: compact ? 12 : 13,
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
    this.actions,
    this.fillViewport = false,
    this.maxContentWidth = 1100,
    this.compactPadding = false,
    this.denseOnPhone = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool fillViewport;
  final double maxContentWidth;
  final bool compactPadding;
  final bool denseOnPhone;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;
    final dense = denseOnPhone && isPhone;

    final outerPadding = dense ? 4.0 : (compactPadding ? 10.0 : 16.0);
    final innerPadding = dense ? 6.0 : (compactPadding ? 12.0 : 18.0);

    final contentCard = Container(
      width: double.infinity,
      height: fillViewport ? double.infinity : null,
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(dense ? 10 : (compactPadding ? 16 : 24)),
        boxShadow: dense
            ? null
            : const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
        border: dense ? Border.all(color: AppColors.border) : null,
      ),
      child: child,
    );

    final centeredContent = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: contentCard,
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.backgroundGradientStart,
            AppColors.backgroundGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dense)
            const VicunhaBrandBar(minimal: true)
          else
            VicunhaBrandBar(subtitle: subtitle),
          if (!dense)
            Material(
              color: AppColors.surfaceAlt,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compactPadding ? 12 : 16,
                  vertical: compactPadding ? 6 : 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackHeader =
                        constraints.maxWidth < AppBreakpoints.phone;
                    final titleWidget = Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compactPadding ? 16 : 18,
                        color: AppColors.textDark,
                      ),
                    );

                    if (actions == null || actions!.isEmpty) {
                      return titleWidget;
                    }

                    final actionsWidget = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment:
                          stackHeader ? WrapAlignment.start : WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions!,
                    );

                    if (stackHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleWidget,
                          const SizedBox(height: 8),
                          actionsWidget,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleWidget),
                        const SizedBox(width: 8),
                        Flexible(child: actionsWidget),
                      ],
                    );
                  },
                ),
              ),
            ),
          if (dense)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

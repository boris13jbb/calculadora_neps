import 'package:flutter/material.dart';

import 'breakpoints.dart';

bool isPhoneLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

double screenSpacing(BuildContext context,
        {double normal = 16, double dense = 8}) =>
    isPhoneLayout(context) ? dense : normal;

EdgeInsets sectionPadding(BuildContext context) =>
    isPhoneLayout(context) ? const EdgeInsets.all(8) : const EdgeInsets.all(14);

double sectionRadius(BuildContext context) => isPhoneLayout(context) ? 10 : 14;

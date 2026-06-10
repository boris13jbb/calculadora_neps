import 'dart:io';

import 'package:shared_preferences_windows/shared_preferences_windows.dart';

void registerPlatformPlugins() {
  if (Platform.isWindows) {
    SharedPreferencesWindows.registerWith();
  }
}

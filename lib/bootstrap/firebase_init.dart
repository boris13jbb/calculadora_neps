import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'app_check_init.dart';

Future<void> initializeFirebaseApp() async {
  if (!DefaultFirebaseOptions.isSupported) return;
  if (Firebase.apps.isNotEmpty) return;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeAppCheck();
}

import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<void> initializeFirebaseApp() async {
  if (Firebase.apps.isNotEmpty) return;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

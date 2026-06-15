// This file is a placeholder.
// To enable Firebase, run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// That command will replace this file with your real Firebase config.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase not configured yet.\n'
      'Run: dart pub global activate flutterfire_cli\n'
      '      flutterfire configure',
    );
  }
}

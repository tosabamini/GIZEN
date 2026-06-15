import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  static String get displayName => currentUser?.displayName ?? '';
  static String get email => currentUser?.email ?? '';

  static Future<String?> signIn(String email, String password) async {
    if (!isAvailable) return 'Firebase not configured yet.';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign in failed.';
    }
  }

  static Future<String?> register(
      String email, String password, String nickname) async {
    if (!isAvailable) return 'Firebase not configured yet.';
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(nickname.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed.';
    }
  }

  static Future<void> signOut() async {
    if (!isAvailable) return;
    await FirebaseAuth.instance.signOut();
  }
}

import 'package:firebase_auth/firebase_auth.dart';

/// Auth layer specifically for recycling centers (web).
///
/// Аналог AuthService из mobile, но:
/// - роль center вместо user;
/// - без Google Sign-In (по описанию для сайта центра достаточно email+password).
class CenterAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // TODO: здесь можно вызывать cloud function setUserRole(role: 'center')
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // TODO: задать displayName по названию центра и вызвать setUserRole('center')
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}


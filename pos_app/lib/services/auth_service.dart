import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../core/config.dart';

class AuthService {
  final fb.FirebaseAuth? _firebaseAuth;

  AuthService._(this._firebaseAuth);

  static AuthService create() {
    if (AppConfig.useFirebase) {
      return AuthService._(fb.FirebaseAuth.instance);
    }
    return AuthService._(null);
  }

  Stream<String?> authStateChanges() {
    if (_firebaseAuth == null) {
      // Local-only fallback: single-user session simulated
      return Stream.value('local-user');
    }
    return _firebaseAuth.authStateChanges().map((u) => u?.uid);
  }

  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    if (_firebaseAuth == null) {
      return 'local-user';
    }
    final cred = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user?.uid;
  }

  Future<void> signOut() async {
    if (_firebaseAuth != null) {
      await _firebaseAuth.signOut();
    }
  }
}
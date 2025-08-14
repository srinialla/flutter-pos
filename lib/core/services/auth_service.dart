import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return AuthResult(
        success: true,
        user: credential.user,
        message: 'Successfully signed in',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
      }

      return AuthResult(
        success: true,
        user: credential.user,
        message: 'Account created successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent to $email',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Update profile
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
        );
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();

      return AuthResult(
        success: true,
        user: _auth.currentUser,
        message: 'Profile updated successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
        );
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return AuthResult(
        success: true,
        message: 'Password changed successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Delete account
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
        );
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete account
      await user.delete();

      return AuthResult(
        success: true,
        message: 'Account deleted successfully',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorCode: e.code,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Get error message from error code
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String message;
  final String? errorCode;

  AuthResult({
    required this.success,
    this.user,
    required this.message,
    this.errorCode,
  });

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message, errorCode: $errorCode)';
  }
}
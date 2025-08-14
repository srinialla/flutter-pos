import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/services/auth_service.dart';
import '../core/services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final SyncService _syncService = SyncService.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      _errorMessage = null;
      
      if (user != null) {
        // Start auto sync when user logs in
        _syncService.startAutoSync();
      }
      
      notifyListeners();
    });
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.success) {
        _user = result.user;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (result.success) {
        _user = result.user;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError('Sign out failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword({required String email}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.resetPassword(email: email);
      
      if (!result.success) {
        _setError(result.message);
      }
      
      return result.success;
    } catch (e) {
      _setError('Password reset failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      if (result.success) {
        _user = result.user;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Profile update failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!result.success) {
        _setError(result.message);
      }

      return result.success;
    } catch (e) {
      _setError('Password change failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.deleteAccount(password: password);

      if (result.success) {
        _user = null;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Account deletion failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() => _clearError();

  // Helper getters
  String get displayName => _user?.displayName ?? 'User';
  String get email => _user?.email ?? '';
  String? get photoURL => _user?.photoURL;
  String get userId => _user?.uid ?? '';
}
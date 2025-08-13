import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/platform_utils.dart';

class SecurityService {
  static SecurityService? _instance;
  static SecurityService get instance => _instance ??= SecurityService._();
  SecurityService._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();
  late final Encrypter _encrypter;
  late final Key _encryptionKey;
  
  bool _isInitialized = false;
  String? _deviceId;
  String? _appSignature;

  // Security state
  bool _isBiometricEnabled = false;
  bool _isDeviceCompromised = false;
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  bool _isLocked = false;

  // Security configuration
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration sessionTimeout = Duration(hours: 8);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize encryption
      await _initializeEncryption();
      
      // Get device information
      await _initializeDeviceInfo();
      
      // Check device security
      await _checkDeviceSecurity();
      
      // Initialize biometric authentication
      await _initializeBiometrics();
      
      _isInitialized = true;
      debugPrint('Security service initialized successfully');
    } catch (e) {
      debugPrint('Security service initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _initializeEncryption() async {
    try {
      // Try to get existing key
      final keyString = await _secureStorage.read(key: 'encryption_key');
      
      if (keyString != null) {
        _encryptionKey = Key.fromBase64(keyString);
      } else {
        // Generate new key
        _encryptionKey = Key.fromSecureRandom(32);
        await _secureStorage.write(
          key: 'encryption_key',
          value: _encryptionKey.base64,
        );
      }
      
      _encrypter = Encrypter(AES(_encryptionKey));
    } catch (e) {
      // Fallback: generate new key
      _encryptionKey = Key.fromSecureRandom(32);
      _encrypter = Encrypter(AES(_encryptionKey));
      debugPrint('Generated fallback encryption key');
    }
  }

  Future<void> _initializeDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (PlatformUtils.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (PlatformUtils.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    } else if (PlatformUtils.isWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      _deviceId = '${webInfo.browserName}_${webInfo.platform}';
    } else {
      _deviceId = 'desktop_${PlatformUtils.getPlatformName()}';
    }
    
    // Generate app signature for integrity checking
    _appSignature = _generateAppSignature();
  }

  Future<void> _checkDeviceSecurity() async {
    if (!PlatformUtils.isMobile) return;

    try {
      // Check if device is rooted/jailbroken (basic check)
      _isDeviceCompromised = await _isDeviceRootedOrJailbroken();
      
      if (_isDeviceCompromised) {
        debugPrint('WARNING: Device appears to be compromised');
        // Log security event
        await _logSecurityEvent('device_compromised', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Device security check failed: $e');
    }
  }

  Future<bool> _isDeviceRootedOrJailbroken() async {
    // Basic root/jailbreak detection
    // In production, use a more comprehensive solution
    try {
      if (PlatformUtils.isAndroid) {
        // Check for common root indicators
        return false; // Simplified for demo
      } else if (PlatformUtils.isIOS) {
        // Check for jailbreak indicators
        return false; // Simplified for demo
      }
    } catch (e) {
      debugPrint('Root/Jailbreak detection error: $e');
    }
    return false;
  }

  Future<void> _initializeBiometrics() async {
    if (!PlatformUtils.isMobile) return;

    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (isAvailable && isDeviceSupported) {
        final biometrics = await _localAuth.getAvailableBiometrics();
        _isBiometricEnabled = biometrics.isNotEmpty;
        
        debugPrint('Biometric authentication available: $_isBiometricEnabled');
        debugPrint('Available biometrics: $biometrics');
      }
    } catch (e) {
      debugPrint('Biometric initialization failed: $e');
      _isBiometricEnabled = false;
    }
  }

  // Biometric Authentication
  Future<BiometricAuthResult> authenticateWithBiometrics({
    required String reason,
    bool stickyAuth = true,
  }) async {
    if (!_isBiometricEnabled) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Biometric authentication not available',
      );
    }

    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedFallbackTitle: 'Use PIN/Password',
        authMessages: const [
          AndroidAuthMessages(
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Biometric not recognized, try again',
            biometricRequiredTitle: 'Biometric Authentication',
            biometricSuccess: 'Authentication successful',
            deviceCredentialsRequiredTitle: 'Device Credentials Required',
            deviceCredentialsSetupDescription: 'Set up device credentials',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Set up biometric authentication',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Set up Touch ID or Face ID',
            lockOut: 'Biometric authentication is disabled',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: stickyAuth,
          sensitiveTransaction: true,
        ),
      );

      if (isAuthenticated) {
        await _logSecurityEvent('biometric_auth_success', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        _resetFailedAttempts();
        return BiometricAuthResult(success: true);
      } else {
        await _handleFailedAuthentication();
        return BiometricAuthResult(
          success: false,
          errorMessage: 'Authentication failed',
        );
      }
    } catch (e) {
      await _logSecurityEvent('biometric_auth_error', {
        'device_id': _deviceId,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Biometric authentication error: $e',
      );
    }
  }

  // Data Encryption/Decryption
  String encryptData(String data) {
    try {
      final iv = IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(data, iv: iv);
      
      // Combine IV and encrypted data
      final combined = '${iv.base64}:${encrypted.base64}';
      return base64Encode(utf8.encode(combined));
    } catch (e) {
      debugPrint('Encryption failed: $e');
      throw SecurityException('Data encryption failed');
    }
  }

  String decryptData(String encryptedData) {
    try {
      final decoded = utf8.decode(base64Decode(encryptedData));
      final parts = decoded.split(':');
      
      if (parts.length != 2) {
        throw SecurityException('Invalid encrypted data format');
      }
      
      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      throw SecurityException('Data decryption failed');
    }
  }

  // Secure data storage
  Future<void> secureWrite(String key, String value) async {
    try {
      final encryptedValue = encryptData(value);
      await _secureStorage.write(key: key, value: encryptedValue);
    } catch (e) {
      debugPrint('Secure write failed: $e');
      throw SecurityException('Failed to write secure data');
    }
  }

  Future<String?> secureRead(String key) async {
    try {
      final encryptedValue = await _secureStorage.read(key: key);
      if (encryptedValue == null) return null;
      
      return decryptData(encryptedValue);
    } catch (e) {
      debugPrint('Secure read failed: $e');
      return null;
    }
  }

  Future<void> secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Secure delete failed: $e');
    }
  }

  // Session Management
  Future<bool> validateSession() async {
    try {
      final sessionData = await secureRead('session_data');
      if (sessionData == null) return false;
      
      final session = json.decode(sessionData);
      final sessionTime = DateTime.parse(session['timestamp']);
      final isExpired = DateTime.now().difference(sessionTime) > sessionTimeout;
      
      if (isExpired) {
        await _invalidateSession();
        return false;
      }
      
      // Update session timestamp
      await _updateSession();
      return true;
    } catch (e) {
      debugPrint('Session validation failed: $e');
      return false;
    }
  }

  Future<void> createSession(String userId) async {
    final sessionData = {
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _deviceId,
      'app_signature': _appSignature,
    };
    
    await secureWrite('session_data', json.encode(sessionData));
  }

  Future<void> _updateSession() async {
    final sessionData = await secureRead('session_data');
    if (sessionData != null) {
      final session = json.decode(sessionData);
      session['timestamp'] = DateTime.now().toIso8601String();
      await secureWrite('session_data', json.encode(session));
    }
  }

  Future<void> _invalidateSession() async {
    await secureDelete('session_data');
    await _logSecurityEvent('session_expired', {
      'device_id': _deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Security monitoring
  Future<void> _handleFailedAuthentication() async {
    _failedAttempts++;
    _lastFailedAttempt = DateTime.now();
    
    await _logSecurityEvent('auth_failed', {
      'device_id': _deviceId,
      'attempt_count': _failedAttempts,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    if (_failedAttempts >= maxFailedAttempts) {
      _isLocked = true;
      await _logSecurityEvent('account_locked', {
        'device_id': _deviceId,
        'lockout_duration': lockoutDuration.inMinutes,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lastFailedAttempt = null;
    _isLocked = false;
  }

  bool get isAccountLocked {
    if (!_isLocked) return false;
    if (_lastFailedAttempt == null) return false;
    
    final lockoutExpired = DateTime.now()
        .difference(_lastFailedAttempt!)
        .compareTo(lockoutDuration) > 0;
    
    if (lockoutExpired) {
      _resetFailedAttempts();
      return false;
    }
    
    return true;
  }

  Duration? get lockoutTimeRemaining {
    if (!isAccountLocked || _lastFailedAttempt == null) return null;
    
    final elapsed = DateTime.now().difference(_lastFailedAttempt!);
    final remaining = lockoutDuration - elapsed;
    
    return remaining.isNegative ? null : remaining;
  }

  // Security event logging
  Future<void> _logSecurityEvent(String eventType, Map<String, dynamic> data) async {
    try {
      final event = {
        'event_type': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        'device_id': _deviceId,
        'app_signature': _appSignature,
        'data': data,
      };
      
      // Store locally for sync
      final events = await _getSecurityEvents();
      events.add(event);
      await secureWrite('security_events', json.encode(events));
      
      // Immediately sync if critical event
      if (_isCriticalEvent(eventType)) {
        // TODO: Implement immediate sync to security monitoring service
        debugPrint('CRITICAL SECURITY EVENT: $eventType');
      }
    } catch (e) {
      debugPrint('Failed to log security event: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getSecurityEvents() async {
    try {
      final eventsData = await secureRead('security_events');
      if (eventsData == null) return [];
      
      final events = json.decode(eventsData) as List;
      return events.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Failed to get security events: $e');
      return [];
    }
  }

  bool _isCriticalEvent(String eventType) {
    const criticalEvents = [
      'device_compromised',
      'account_locked',
      'unauthorized_access_attempt',
      'data_breach_attempt',
    ];
    return criticalEvents.contains(eventType);
  }

  // Utility methods
  String _generateAppSignature() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final combined = '$_deviceId$timestamp$random';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  String generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // Getters
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isDeviceCompromised => _isDeviceCompromised;
  int get failedAttempts => _failedAttempts;
  String? get deviceId => _deviceId;
  bool get isInitialized => _isInitialized;

  // Clean up
  Future<void> dispose() async {
    // Clear sensitive data from memory
    _encryptionKey.bytes.fillRange(0, _encryptionKey.bytes.length, 0);
    _deviceId = null;
    _appSignature = null;
    _isInitialized = false;
  }
}

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}
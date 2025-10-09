import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver_cerca/services/auth_service.dart';

class StorageService {
  static const String _tokenKey = 'driver_token';
  static const String _driverIdKey = 'driver_id';
  static const String _driverEmailKey = 'driver_email';
  static const String _driverNameKey = 'driver_name';
  static const String _isLoggedInKey = 'is_logged_in';

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      print('📱 Storage service initialized successfully');
    } catch (e) {
      print('❌ Error initializing storage service: $e');
      // Retry once after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        _prefs = await SharedPreferences.getInstance();
        print('📱 Storage service initialized on retry');
      } catch (e2) {
        print('❌ Failed to initialize storage service after retry: $e2');
        throw Exception('Failed to initialize SharedPreferences: $e2');
      }
    }
  }

  /// Store authentication data after successful login
  static Future<bool> storeAuthData({
    required String token,
    required String driverId,
    required String email,
    required String name,
  }) async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) {
          print('❌ Failed to initialize SharedPreferences');
          return false;
        }
      }

      final success = await Future.wait([
        _prefs!.setString(_tokenKey, token),
        _prefs!.setString(_driverIdKey, driverId),
        _prefs!.setString(_driverEmailKey, email),
        _prefs!.setString(_driverNameKey, name),
        _prefs!.setBool(_isLoggedInKey, true),
      ]);

      final allSuccess = success.every((result) => result == true);

      if (allSuccess) {
        print('✅ Auth data stored successfully');
        print('📦 Token: ${token.substring(0, 20)}...');
        print('📦 Driver ID: $driverId');
        print('📦 Email: $email');
        print('📦 Name: $name');
      } else {
        print('❌ Failed to store some auth data');
      }

      return allSuccess;
    } catch (e) {
      print('❌ Error storing auth data: $e');
      return false;
    }
  }

  /// Get stored authentication token
  static Future<String?> getToken() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return null;
      }
      final token = _prefs!.getString(_tokenKey);
      print(
        '🔑 Retrieved token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
      );
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  /// Get stored driver ID
  static Future<String?> getDriverId() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return null;
      }
      final driverId = _prefs!.getString(_driverIdKey);
      print('👤 Retrieved driver ID: $driverId');
      return driverId;
    } catch (e) {
      print('❌ Error getting driver ID: $e');
      return null;
    }
  }

  /// Get stored driver email
  static Future<String?> getDriverEmail() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return null;
      }
      return _prefs!.getString(_driverEmailKey);
    } catch (e) {
      print('❌ Error getting driver email: $e');
      return null;
    }
  }

  /// Get stored driver name
  static Future<String?> getDriverName() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return null;
      }
      return _prefs!.getString(_driverNameKey);
    } catch (e) {
      print('❌ Error getting driver name: $e');
      return null;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return false;
      }
      final isLoggedIn = _prefs!.getBool(_isLoggedInKey) ?? false;
      final hasToken = await getToken() != null;
      final hasDriverId = await getDriverId() != null;

      final result = isLoggedIn && hasToken && hasDriverId;
      print(
        '🔍 Login status check: $result (isLoggedIn: $isLoggedIn, hasToken: $hasToken, hasDriverId: $hasDriverId)',
      );

      return result;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  /// Get stored user data as DriverUser object
  static Future<DriverUser?> getStoredUser() async {
    try {
      final email = await getDriverEmail();
      final name = await getDriverName();
      final driverId = await getDriverId();

      if (email != null && name != null && driverId != null) {
        return DriverUser(
          id: driverId,
          email: email,
          name: name,
          isActive: true,
        );
      }

      return null;
    } catch (e) {
      print('❌ Error getting stored user: $e');
      return null;
    }
  }

  /// Clear all stored authentication data (logout)
  static Future<bool> clearAuthData() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return false;
      }

      final success = await Future.wait([
        _prefs!.remove(_tokenKey),
        _prefs!.remove(_driverIdKey),
        _prefs!.remove(_driverEmailKey),
        _prefs!.remove(_driverNameKey),
        _prefs!.setBool(_isLoggedInKey, false),
      ]);

      final allSuccess = success.every((result) => result == true);

      if (allSuccess) {
        print('✅ Auth data cleared successfully');
      } else {
        print('❌ Failed to clear some auth data');
      }

      return allSuccess;
    } catch (e) {
      print('❌ Error clearing auth data: $e');
      return false;
    }
  }

  /// Get all stored data for debugging
  static Future<Map<String, dynamic>> getAllStoredData() async {
    try {
      if (_prefs == null) {
        await initialize();
        if (_prefs == null) return {};
      }

      return {
        'token': _prefs!.getString(_tokenKey),
        'driverId': _prefs!.getString(_driverIdKey),
        'email': _prefs!.getString(_driverEmailKey),
        'name': _prefs!.getString(_driverNameKey),
        'isLoggedIn': _prefs!.getBool(_isLoggedInKey),
      };
    } catch (e) {
      print('❌ Error getting all stored data: $e');
      return {};
    }
  }

  /// Validate stored token (basic check)
  static Future<bool> isTokenValid() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      // Basic JWT token validation (check if it has 3 parts separated by dots)
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // You can add more sophisticated JWT validation here
      // For now, just check if it exists and has correct format
      return true;
    } catch (e) {
      print('❌ Error validating token: $e');
      return false;
    }
  }
}

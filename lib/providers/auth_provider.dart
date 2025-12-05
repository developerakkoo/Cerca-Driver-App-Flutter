import 'package:flutter/foundation.dart';
import 'package:driver_cerca/models/driver_model.dart';
import 'package:driver_cerca/services/auth_service.dart';

/// AuthProvider manages authentication state and profile operations
class AuthProvider extends ChangeNotifier {
  DriverModel? _driver;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  // Getters
  DriverModel? get driver => _driver;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize provider and load stored user
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final storedUser = await AuthService.getStoredUser();
      if (storedUser != null) {
        _driver = storedUser;
        _isAuthenticated = true;
        // Fetch full profile from API
        await getProfile(storedUser.id);
      }
    } catch (e) {
      _setError('Failed to load stored user: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Register new driver
  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required List<double> coordinates,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        coordinates: coordinates,
      );

      if (result.isSuccess && result.user != null) {
        _driver = result.user;
        // Note: Registration doesn't return token, user needs to login
        _isAuthenticated = false;
        notifyListeners();
      } else {
        _setError(result.message ?? 'Registration failed');
      }

      return result;
    } catch (e) {
      final errorMsg = 'Registration failed: $e';
      _setError(errorMsg);
      return AuthResult.failure(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Login driver
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.login(
        email: email,
        password: password,
      );

      if (result.isSuccess && result.user != null) {
        _driver = result.user;
        _isAuthenticated = true;
        // Fetch full profile from API
        if (result.user != null) {
          await getProfile(result.user!.id);
        }
        notifyListeners();
      } else {
        _setError(result.message ?? 'Login failed');
      }

      return result;
    } catch (e) {
      final errorMsg = 'Login failed: $e';
      _setError(errorMsg);
      return AuthResult.failure(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Logout driver
  Future<bool> logout() async {
    _setLoading(true);
    _clearError();

    try {
      final success = await AuthService.logout();
      if (success) {
        _driver = null;
        _isAuthenticated = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('Logout failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get driver profile from API
  Future<void> getProfile(String driverId) async {
    _setLoading(true);
    _clearError();

    try {
      final profile = await AuthService.getDriverProfile(driverId);
      if (profile != null) {
        _driver = profile;
        _isAuthenticated = true;
        notifyListeners();
      } else {
        _setError('Failed to fetch profile');
      }
    } catch (e) {
      _setError('Failed to fetch profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update driver profile
  Future<bool> updateProfile({
    required String driverId,
    String? name,
    String? email,
    String? phone,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedProfile = await AuthService.updateDriverProfile(
        driverId: driverId,
        name: name,
        email: email,
        phone: phone,
      );

      if (updatedProfile != null) {
        _driver = updatedProfile;
        notifyListeners();
        return true;
      } else {
        _setError('Failed to update profile');
        return false;
      }
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload driver documents
  Future<List<String>?> uploadDocuments({
    required String driverId,
    required List<String> filePaths,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final documents = await AuthService.uploadDocuments(
        driverId: driverId,
        filePaths: filePaths,
      );

      if (documents != null && _driver != null) {
        // Update driver with new documents
        _driver = _driver!.copyWith(documents: documents);
        notifyListeners();
      }

      return documents;
    } catch (e) {
      _setError('Failed to upload documents: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update vehicle information
  Future<bool> updateVehicleInfo({
    required String driverId,
    required String make,
    required String model,
    required int year,
    required String color,
    required String licensePlate,
    required VehicleType vehicleType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final vehicleInfo = await AuthService.updateVehicleInfo(
        driverId: driverId,
        make: make,
        model: model,
        year: year,
        color: color,
        licensePlate: licensePlate,
        vehicleType: vehicleType,
      );

      if (vehicleInfo != null && _driver != null) {
        _driver = _driver!.copyWith(vehicleInfo: vehicleInfo);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to update vehicle info');
        return false;
      }
    } catch (e) {
      _setError('Failed to update vehicle info: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Auto-login using stored credentials
  Future<AuthResult> autoLogin() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.autoLogin();
      if (result.isSuccess && result.user != null) {
        _driver = result.user;
        _isAuthenticated = true;
        notifyListeners();
      } else {
        _setError(result.message ?? 'Auto-login failed');
        _isAuthenticated = false;
      }
      return result;
    } catch (e) {
      final errorMsg = 'Auto-login failed: $e';
      _setError(errorMsg);
      _isAuthenticated = false;
      return AuthResult.failure(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Load stored user from storage
  Future<void> loadStoredUser() async {
    try {
      final storedUser = await AuthService.getStoredUser();
      if (storedUser != null) {
        _driver = storedUser;
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load stored user: $e');
    }
  }

  /// Clear error state
  void clearError() {
    _clearError();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}


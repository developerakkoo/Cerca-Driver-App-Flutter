import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/models/driver_model.dart';

class AuthService {
  static final Dio _dio = Dio();

  // Initialize Dio with base configuration
  static Future<void> initialize() async {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.sendTimeout = const Duration(seconds: 10);

    // Initialize storage service with error handling
    try {
      await StorageService.initialize();
    } catch (e) {
      print('❌ Failed to initialize storage service: $e');
      // Continue without storage service for now
    }

    // Add interceptors for logging and error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🚀 Request: ${options.method} ${options.uri}');
          print('📦 Headers: ${options.headers}');
          print('📄 Data: ${options.data}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            '✅ Response: ${response.statusCode} ${response.requestOptions.uri}',
          );
          print('📦 Data: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ Error: ${error.message}');
          print('📦 Response: ${error.response?.data}');
          handler.next(error);
        },
      ),
    );
  }

  /// Register new driver
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required List<double> coordinates, // [longitude, latitude]
  }) async {
    try {
      print('📝 Attempting registration for: $email');

      final response = await _dio.post(
        '/drivers',
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'location': {'coordinates': coordinates},
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;

        if (data['id'] != null) {
          final driver = DriverModel.fromJson(data['id']);
          print('✅ Registration successful for: ${driver.name}');

          // Note: API doesn't return token on registration
          // User needs to login after registration
          return AuthResult.success(
            user: driver,
            token: null,
            message: data['message'] ?? 'Driver added successfully',
          );
        } else {
          return AuthResult.failure('Invalid response from server');
        }
      } else {
        final message = response.data['message'] ?? 'Registration failed';
        print('❌ Registration failed: $message');
        return AuthResult.failure(message);
      }
    } on DioException catch (e) {
      print('❌ DioException during registration: ${e.message}');

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return AuthResult.failure(
          'Connection timeout. Please check your internet connection.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return AuthResult.failure(
          'Unable to connect to server. Please check your internet connection.',
        );
      } else if (e.response?.statusCode == 400) {
        final message =
            e.response?.data['message'] ??
            'Driver with this phone number already exists';
        return AuthResult.failure(message);
      } else if (e.response?.statusCode == 500) {
        return AuthResult.failure('Server error. Please try again later.');
      } else {
        final message =
            e.response?.data['message'] ?? e.message ?? 'Registration failed';
        return AuthResult.failure(message);
      }
    } catch (e) {
      print('❌ Unexpected error during registration: $e');
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Login driver with email and password
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting login for: $email');

      final response = await _dio.post(
        '/drivers/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check if login was successful
        if (data['success'] == true ||
            data['status'] == 'success' ||
            data['message'] == 'Login successful') {
          // Extract user data and token
          final token =
              data['token'] ?? data['accessToken'] ?? data['access_token'];
          final driverId = data['id'] ?? data['driverId'] ?? data['_id'];
          final email = data['email'] ?? '';
          final name = data['name'] ?? data['driverName'] ?? 'Driver';

          print('✅ Login successful for: $name');

          // Store authentication data
          await StorageService.storeAuthData(
            token: token,
            driverId: driverId,
            email: email,
            name: name,
          );

          // Create driver object with minimal data
          // Full profile will be fetched separately
          final driver = DriverModel(
            id: driverId,
            email: email,
            name: name,
            phone: '',
            location: LocationModel(coordinates: [0.0, 0.0]),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          return AuthResult.success(user: driver, token: token);
        } else {
          final message = data['message'] ?? data['error'] ?? 'Login failed';
          print('❌ Login failed: $message');
          return AuthResult.failure(message);
        }
      } else {
        final message = response.data['message'] ?? 'Login failed';
        print('❌ Login failed with status: ${response.statusCode}');
        return AuthResult.failure(message);
      }
    } on DioException catch (e) {
      print('❌ DioException during login: ${e.message}');

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return AuthResult.failure(
          'Connection timeout. Please check your internet connection.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return AuthResult.failure(
          'Unable to connect to server. Please check your internet connection.',
        );
      } else if (e.response?.statusCode == 401) {
        return AuthResult.failure('Invalid email or password.');
      } else if (e.response?.statusCode == 404) {
        return AuthResult.failure('Login endpoint not found.');
      } else if (e.response?.statusCode == 500) {
        return AuthResult.failure('Server error. Please try again later.');
      } else {
        final message =
            e.response?.data['message'] ?? e.message ?? 'Login failed';
        return AuthResult.failure(message);
      }
    } catch (e) {
      print('❌ Unexpected error during login: $e');
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Logout driver
  static Future<bool> logout() async {
    try {
      // Clear stored authentication data
      final success = await StorageService.clearAuthData();
      print('🚪 Logging out user: ${success ? 'Success' : 'Failed'}');
      return success;
    } catch (e) {
      print('❌ Error during logout: $e');
      return false;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      return await StorageService.isLoggedIn();
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  /// Get stored user data
  static Future<DriverModel?> getStoredUser() async {
    try {
      final userData = await StorageService.getStoredUser();
      if (userData != null) {
        // Convert old DriverUser to DriverModel if needed
        return DriverModel(
          id: userData.id,
          name: userData.name,
          email: userData.email,
          phone: userData.phone ?? '',
          location: LocationModel(coordinates: [0.0, 0.0]),
          isActive: userData.isActive,
          createdAt: userData.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('❌ Error getting stored user: $e');
      return null;
    }
  }

  /// Get driver profile from API
  static Future<DriverModel?> getDriverProfile(String driverId) async {
    try {
      print('📥 Fetching driver profile for: $driverId');

      final response = await _dio.get('/drivers/$driverId');

      if (response.statusCode == 200) {
        final driver = DriverModel.fromJson(response.data);
        print('✅ Driver profile fetched successfully');
        return driver;
      } else {
        print('❌ Failed to fetch profile: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ DioException fetching profile: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error fetching profile: $e');
      return null;
    }
  }

  /// Update driver profile
  static Future<DriverModel?> updateDriverProfile({
    required String driverId,
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      print('📝 Updating driver profile for: $driverId');

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;

      final response = await _dio.put('/drivers/$driverId', data: updateData);

      if (response.statusCode == 200) {
        final driver = DriverModel.fromJson(response.data);
        print('✅ Profile updated successfully');

        // Update stored data
        await StorageService.storeAuthData(
          token: await StorageService.getToken() ?? '',
          driverId: driver.id,
          email: driver.email,
          name: driver.name,
        );

        return driver;
      } else {
        print('❌ Failed to update profile: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ DioException updating profile: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return null;
    }
  }

  /// Upload driver documents
  static Future<List<String>?> uploadDocuments({
    required String driverId,
    required List<String> filePaths,
  }) async {
    try {
      print('📤 Uploading ${filePaths.length} documents for driver: $driverId');

      // Create multipart files
      final List<MultipartFile> files = [];
      for (String path in filePaths) {
        files.add(await MultipartFile.fromFile(path));
      }

      final formData = FormData.fromMap({'documents': files});

      final response = await _dio.post(
        '/drivers/$driverId/documents',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.statusCode == 200) {
        final documents = List<String>.from(response.data['documents']);
        print('✅ Documents uploaded successfully: ${documents.length} files');
        return documents;
      } else {
        print('❌ Failed to upload documents: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ DioException uploading documents: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error uploading documents: $e');
      return null;
    }
  }

  /// Update vehicle information
  static Future<VehicleInfo?> updateVehicleInfo({
    required String driverId,
    required String make,
    required String model,
    required int year,
    required String color,
    required String licensePlate,
    required VehicleType vehicleType,
  }) async {
    try {
      print('🚗 Updating vehicle info for driver: $driverId');

      final response = await _dio.patch(
        '/drivers/$driverId/vehicle',
        data: {
          'make': make,
          'model': model,
          'year': year,
          'color': color,
          'licensePlate': licensePlate,
          'vehicleType': vehicleType.value,
        },
      );

      if (response.statusCode == 200) {
        final vehicleInfo = VehicleInfo.fromJson(response.data['vehicleInfo']);
        print('✅ Vehicle info updated successfully');
        return vehicleInfo;
      } else {
        print('❌ Failed to update vehicle info: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ DioException updating vehicle info: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error updating vehicle info: $e');
      return null;
    }
  }

  /// Auto-login using stored credentials
  static Future<AuthResult> autoLogin() async {
    try {
      final isLoggedIn = await StorageService.isLoggedIn();
      final token = await StorageService.getToken();
      final driverId = await StorageService.getDriverId();

      if (isLoggedIn && token != null && driverId != null) {
        // Fetch full driver profile from API
        final driver = await getDriverProfile(driverId);

        if (driver != null) {
          print('🔄 Auto-login successful for: ${driver.name}');
          return AuthResult.success(user: driver, token: token);
        } else {
          print('❌ Auto-login failed: Could not fetch profile');
          return AuthResult.failure('Failed to fetch driver profile');
        }
      } else {
        print('❌ Auto-login failed: Missing credentials');
        return AuthResult.failure('No stored credentials found');
      }
    } catch (e) {
      print('❌ Error during auto-login: $e');
      return AuthResult.failure('Auto-login failed');
    }
  }
}

/// Driver user model (kept for backward compatibility with StorageService)
class DriverUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? profileImage;
  final bool isActive;
  final DateTime? createdAt;

  DriverUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.profileImage,
    required this.isActive,
    this.createdAt,
  });

  factory DriverUser.fromJson(Map<String, dynamic> json) {
    return DriverUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? json['fullName'] ?? json['driverName'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'],
      profileImage: json['profileImage'] ?? json['avatar'] ?? json['image'],
      isActive: json['isActive'] ?? json['active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DriverUser(id: $id, email: $email, name: $name, isActive: $isActive)';
  }
}

/// Authentication result
class AuthResult {
  final bool isSuccess;
  final String? message;
  final DriverModel? user;
  final String? token;

  AuthResult._({required this.isSuccess, this.message, this.user, this.token});

  factory AuthResult.success({
    required DriverModel user,
    String? token,
    String? message,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      token: token,
      message: message,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, message: message);
  }

  @override
  String toString() {
    return 'AuthResult(isSuccess: $isSuccess, message: $message, user: $user)';
  }
}

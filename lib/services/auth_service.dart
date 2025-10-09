import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:driver_cerca/services/storage_service.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.14:3000';
  static final Dio _dio = Dio();

  // Initialize Dio with base configuration
  static Future<void> initialize() async {
    _dio.options.baseUrl = baseUrl;
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

  /// Login driver with email and password
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting login for: $email');

      final response = await _dio.post(
        '/driver/login',
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

          // Create user object
          final user = DriverUser(
            id: driverId,
            email: email,
            name: name,
            isActive: true,
          );

          return AuthResult.success(user: user, token: token);
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
  static Future<DriverUser?> getStoredUser() async {
    try {
      return await StorageService.getStoredUser();
    } catch (e) {
      print('❌ Error getting stored user: $e');
      return null;
    }
  }

  /// Auto-login using stored credentials
  static Future<AuthResult> autoLogin() async {
    try {
      final isLoggedIn = await StorageService.isLoggedIn();
      final token = await StorageService.getToken();
      final user = await StorageService.getStoredUser();

      if (isLoggedIn && token != null && user != null) {
        print('🔄 Auto-login successful for: ${user.name}');
        return AuthResult.success(user: user, token: token);
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

/// Driver user model
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
  final DriverUser? user;
  final String? token;

  AuthResult._({required this.isSuccess, this.message, this.user, this.token});

  factory AuthResult.success({
    required DriverUser user,
    required String token,
  }) {
    return AuthResult._(isSuccess: true, user: user, token: token);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, message: message);
  }

  @override
  String toString() {
    return 'AuthResult(isSuccess: $isSuccess, message: $message, user: $user)';
  }
}

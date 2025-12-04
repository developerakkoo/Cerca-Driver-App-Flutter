/// constants.dart
/// This file contains app-wide constant values.

import 'package:flutter/material.dart';

// App Colors
class AppColors {
  static const primary = Color(0xFF333652);
  static const secondary = Color(0xFFDB6A42);
  static const background = Color(0xFFF5F5F5);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

// App Strings
class AppStrings {
  static const appName = 'Driver Cerca';
  static const welcomeMessage = 'Welcome to Driver Cerca!';
}

// App Dimensions
class AppDimensions {
  static const double padding = 16.0;
  static const double borderRadius = 8.0;
}

// API Endpoints
class ApiEndpoints {
  static const baseUrl = 'https://api.myserverdevops.com';
  // static const baseUrl = 'http://192.168.1.14:3000';
  static const login = '$baseUrl/auth/login';
  static const register = '$baseUrl/auth/register';
}

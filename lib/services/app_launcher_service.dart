import 'package:flutter/services.dart';

/// Service to bring the app to foreground from background
class AppLauncherService {
  static const platform = MethodChannel(
    'com.example.driver_cerca/app_launcher',
  );

  /// Bring the app to foreground
  static Future<bool> bringAppToForeground() async {
    try {
      print('📱 Attempting to bring app to foreground...');
      final result = await platform.invokeMethod('bringAppToForeground');
      print('✅ App brought to foreground: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Failed to bring app to foreground: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error bringing app to foreground: $e');
      return false;
    }
  }
}

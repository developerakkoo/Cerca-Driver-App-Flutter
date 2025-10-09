import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  static const String _overlayPermissionTitle = "Overlay Permission Required";
  static const String _overlayPermissionMessage =
      "This app needs overlay permission to show ride requests when you're using other apps. "
      "Please grant this permission to continue.";

  static const String _backgroundPermissionTitle =
      "Background Activity Permission";
  static const String _backgroundPermissionMessage =
      "This app needs background activity permission to receive ride requests when the app is not in use. "
      "This is essential for the driver app to function properly.";

  static const String _batteryPermissionTitle = "Battery Optimization";
  static const String _batteryPermissionMessage =
      "To ensure you receive ride requests reliably, please disable battery optimization for this app. "
      "This prevents the system from killing the app in the background.";

  static const String _locationPermissionTitle = "Location Permission";
  static const String _locationPermissionMessage =
      "This app needs location permission to track your position and provide accurate ride matching. "
      "Your location is essential for the driver app to function properly.";

  /// Shows a comprehensive permission dialog explaining all required permissions
  static Future<bool> showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Permissions Required'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To provide the best driver experience, this app needs the following permissions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildPermissionItem(
                      icon: Icons.picture_in_picture,
                      title: 'Overlay Permission',
                      description: 'Show ride requests over other apps',
                      color: Colors.orange,
                    ),

                    const SizedBox(height: 12),

                    _buildPermissionItem(
                      icon: Icons.electrical_services,
                      title: 'Background Activity',
                      description: 'Receive requests when app is closed',
                      color: Colors.green,
                    ),

                    const SizedBox(height: 12),

                    _buildPermissionItem(
                      icon: Icons.battery_charging_full,
                      title: 'Battery Optimization',
                      description: 'Prevent app from being killed',
                      color: Colors.red,
                    ),

                    const SizedBox(height: 12),

                    _buildPermissionItem(
                      icon: Icons.location_on,
                      title: 'Location Permission',
                      description: 'Track driver position for ride matching',
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These permissions are essential for the driver app to function properly.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Grant Permissions'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  static Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Requests all required permissions in sequence
  static Future<Map<String, bool>> requestAllPermissions() async {
    final Map<String, bool> results = {};

    // 1. Overlay Permission
    results['overlay'] = await requestOverlayPermission();

    // 2. Background Activity Permission
    results['background'] = await requestBackgroundPermission();

    // 3. Battery Optimization
    results['battery'] = await requestBatteryOptimization();

    // 4. Location Permission
    results['location'] = await requestLocationPermission();

    return results;
  }

  /// Requests overlay permission
  static Future<bool> requestOverlayPermission() async {
    try {
      if (Platform.isAndroid) {
        final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();

        if (!isGranted) {
          final bool? result = await FlutterOverlayWindow.requestPermission();
          return result ?? false;
        }
        return true;
      }
      return true; // iOS doesn't need overlay permission
    } catch (e) {
      print('Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Requests background activity permission
  static Future<bool> requestBackgroundPermission() async {
    try {
      if (Platform.isAndroid) {
        // Request notification permission (required for background services)
        final status = await Permission.notification.request();

        // Request exact alarm permission (for background tasks)
        final exactAlarmStatus = await Permission.scheduleExactAlarm.request();

        return status.isGranted && exactAlarmStatus.isGranted;
      }
      return true; // iOS handles this differently
    } catch (e) {
      print('Error requesting background permission: $e');
      return false;
    }
  }

  /// Requests battery optimization exemption
  static Future<bool> requestBatteryOptimization() async {
    try {
      if (Platform.isAndroid) {
        // Check if battery optimization is disabled
        final bool isIgnoringBatteryOptimizations =
            await Permission.ignoreBatteryOptimizations.isGranted;

        if (!isIgnoringBatteryOptimizations) {
          // Request to ignore battery optimizations
          final status = await Permission.ignoreBatteryOptimizations.request();
          return status.isGranted;
        }
        return true;
      }
      return true; // iOS doesn't have battery optimization
    } catch (e) {
      print('Error requesting battery optimization: $e');
      return false;
    }
  }

  /// Requests location permission
  static Future<bool> requestLocationPermission() async {
    try {
      if (Platform.isAndroid) {
        // Request location permission
        final status = await Permission.location.request();
        return status.isGranted;
      }
      // For iOS, location permissions are handled differently
      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Shows permission status dialog
  static Future<void> showPermissionStatus(
    BuildContext context,
    Map<String, bool> results,
  ) async {
    final List<String> granted = [];
    final List<String> denied = [];

    results.forEach((permission, isGranted) {
      if (isGranted) {
        granted.add(_getPermissionDisplayName(permission));
      } else {
        denied.add(_getPermissionDisplayName(permission));
      }
    });

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Permission Status'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (granted.isNotEmpty) ...[
                const Text(
                  'Granted Permissions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ...granted.map(
                  (permission) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(permission),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (denied.isNotEmpty) ...[
                const Text(
                  'Denied Permissions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                ...denied.map(
                  (permission) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.close, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(permission),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some permissions were denied. The app may not function properly.',
                          style: TextStyle(fontSize: 14, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (denied.isNotEmpty)
              TextButton(
                onPressed: () async {
                  try {
                    await openAppSettings();
                  } catch (e) {
                    print('Error opening app settings: $e');
                    // Fallback: show a message to manually open settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please manually open app settings to grant permissions',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Open Settings'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static String _getPermissionDisplayName(String permission) {
    switch (permission) {
      case 'overlay':
        return 'Overlay Permission';
      case 'background':
        return 'Background Activity';
      case 'battery':
        return 'Battery Optimization';
      default:
        return permission;
    }
  }

  /// Checks if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    final results = await requestAllPermissions();
    return results.values.every((isGranted) => isGranted);
  }
}

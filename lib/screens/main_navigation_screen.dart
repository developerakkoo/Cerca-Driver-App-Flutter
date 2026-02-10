import 'package:flutter/material.dart';
import 'package:driver_cerca/screens/home_screen.dart';
import 'package:driver_cerca/screens/rides_screen.dart';
import 'package:driver_cerca/screens/earnings_screen.dart';
import 'package:driver_cerca/screens/profile_screen.dart';
import 'package:driver_cerca/screens/active_ride_screen.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/providers/socket_provider.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RidesScreen(),
    const EarningsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // ✅ Post-login initialization flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAfterLogin();
    });

    // Register global callback for ride accepted from overlay
    // This ensures navigation works even when app is in background
    SocketService.onRideAccepted = (ride) {
      print('🚀 [MainNav] Ride accepted callback triggered');
      print('   Ride ID: ${ride.id}');
      print('   Booking Type: ${ride.bookingType?.displayName ?? "INSTANT"}');

      // Check if this is a Full Day booking
      final isFullDayBooking = ride.isFullDayBooking();

      if (isFullDayBooking) {
        // For Full Day bookings: Don't navigate, just show toast
        print(
          '📅 Full Day booking accepted - not navigating to active ride screen',
        );
        // The booking will appear in Upcoming Bookings screen automatically
      } else {
        // For instant rides: Navigate to active ride screen
        print('🚗 Instant ride accepted - navigating to ActiveRideScreen');

        // Switch to Rides tab
        if (mounted) {
          setState(() {
            _currentIndex = 1; // Index 1 is Rides tab
          });

          // Navigate to active ride screen
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveRideScreen(ride: ride),
                ),
              );
            }
          });
        }
      }

      print('✅ Ride accepted handling completed');
    };

    // Check if there's a pending accepted ride from background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingAcceptedRide();
    });
  }

  /// Initialize SocketProvider and sync driver status after login
  Future<void> _initializeAfterLogin() async {
    print('🚀 [MainNav] Starting post-login initialization...');

    try {
      final socketProvider = Provider.of<SocketProvider>(
        context,
        listen: false,
      );

      // Step 1: Initialize SocketProvider if not already initialized
      if (!SocketService.isInitialized) {
        print('📦 [MainNav] Initializing SocketProvider...');
        await socketProvider.initialize();
        print('✅ [MainNav] SocketProvider initialized');
      } else {
        print('ℹ️ [MainNav] SocketProvider already initialized');
      }

      // Step 2: Connect socket if not already connected
      if (!socketProvider.isConnected) {
        print('🔌 [MainNav] Connecting socket...');
        await socketProvider.connect();
        print('✅ [MainNav] Socket connection attempt completed');
        print('   Socket ID: ${socketProvider.socketId}');
        print('   Connection state: ${socketProvider.connectionState}');
      } else {
        print('✅ [MainNav] Socket already connected');
        print('   Socket ID: ${socketProvider.socketId}');
      }

      // Step 3: Load saved driver status from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedIsOnline = prefs.getBool('driver_is_online') ?? false;
      print(
        '💾 [MainNav] Loaded saved driver status: ${savedIsOnline ? "ONLINE" : "OFFLINE"}',
      );

      // Step 4: Sync driver status with SocketProvider
      if (socketProvider.isDriverOnline != savedIsOnline) {
        print('🔄 [MainNav] Syncing driver status with SocketProvider...');
        socketProvider.setDriverOnline(savedIsOnline);
        print(
          '✅ [MainNav] Driver status synced: ${savedIsOnline ? "ONLINE" : "OFFLINE"}',
        );
      } else {
        print('✅ [MainNav] Driver status already in sync');
      }

      // Step 5: If driver was online, ensure socket is connected
      if (savedIsOnline && !socketProvider.isConnected) {
        print(
          '⚠️ [MainNav] Driver was online but socket disconnected, reconnecting...',
        );
        await socketProvider.connect();
      }

      print('✅ [MainNav] Post-login initialization completed');
      print('   Driver online: ${socketProvider.isDriverOnline}');
      print('   Socket connected: ${socketProvider.isConnected}');
      print('   Socket ID: ${socketProvider.socketId}');
    } catch (e) {
      print('❌ [MainNav] Error during post-login initialization: $e');
    }
  }

  void _checkPendingAcceptedRide() {
    final acceptedRide = SocketService.getAcceptedRideForNavigation();
    if (acceptedRide != null) {
      print('📱 Found pending accepted ride, checking type...');
      print('   Ride ID: ${acceptedRide.id}');
      print(
        '   Booking Type: ${acceptedRide.bookingType?.displayName ?? "INSTANT"}',
      );

      // Check if this is a Full Day booking
      final isFullDayBooking = acceptedRide.isFullDayBooking();

      // Clear it first
      SocketService.clearAcceptedRideForNavigation();

      if (isFullDayBooking) {
        // For Full Day bookings: Don't navigate
        print(
          '📅 Full Day booking - not navigating, will appear in Upcoming Bookings',
        );
      } else {
        // For instant rides: Navigate to active ride screen
        print('🚗 Instant ride - navigating to ActiveRideScreen');

        // Switch to Rides tab first
        setState(() {
          _currentIndex = 1; // Index 1 is Rides tab
        });

        // Then navigate to active ride screen after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActiveRideScreen(ride: acceptedRide),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Rides',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

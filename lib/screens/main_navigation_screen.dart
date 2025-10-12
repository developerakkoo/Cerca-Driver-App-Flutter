import 'package:flutter/material.dart';
import 'package:driver_cerca/screens/home_screen.dart';
import 'package:driver_cerca/screens/rides_screen.dart';
import 'package:driver_cerca/screens/earnings_screen.dart';
import 'package:driver_cerca/screens/profile_screen.dart';
import 'package:driver_cerca/screens/active_ride_screen.dart';
import 'package:driver_cerca/services/socket_service.dart';

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

    // Register global callback for ride accepted from overlay
    // This ensures navigation works even when app is in background
    SocketService.onRideAccepted = (ride) {
      print(
        '🚀 [MainNav] Navigating to ActiveRideScreen from overlay acceptance',
      );
      print('   Ride ID: ${ride.id}');

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

      print('✅ Navigation command sent');
    };

    // Check if there's a pending accepted ride from background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingAcceptedRide();
    });
  }

  void _checkPendingAcceptedRide() {
    final acceptedRide = SocketService.getAcceptedRideForNavigation();
    if (acceptedRide != null) {
      print('📱 Found pending accepted ride, navigating now...');
      print('   Ride ID: ${acceptedRide.id}');

      // Clear it first
      SocketService.clearAcceptedRideForNavigation();

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
          selectedItemColor: Colors.indigo[600],
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

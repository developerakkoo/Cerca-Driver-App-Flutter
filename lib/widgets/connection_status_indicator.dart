import 'package:flutter/material.dart';
import 'package:driver_cerca/services/socket_service.dart';

/// ConnectionStatusIndicator shows a small indicator of socket connection status
class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = SocketService.isConnected;

    // Listen for connection status changes
    SocketService.onConnectionStatusChanged = (connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
            boxShadow: _isConnected
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _isConnected ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 12,
            color: _isConnected ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

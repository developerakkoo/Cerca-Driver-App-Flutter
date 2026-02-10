import 'package:flutter/material.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/widgets/rating_dialog.dart';
import 'package:driver_cerca/constants/constants.dart' as AppConstants;
import 'package:driver_cerca/services/ride_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/services/socket_service.dart';

/// Post-Ride Payment Screen
/// Displays payment collection UI for both CASH and RAZORPAY (Pay Online) payment methods
class CashCollectionScreen extends StatefulWidget {
  final RideModel ride;

  const CashCollectionScreen({
    super.key,
    required this.ride,
  });

  @override
  State<CashCollectionScreen> createState() => _CashCollectionScreenState();
}

class _CashCollectionScreenState extends State<CashCollectionScreen> {
  final TextEditingController _cashReceivedController = TextEditingController();
  double? _changeAmount;
  bool _paymentCompleted = false;
  String? _paymentId;
  Function(String?, double?, String?, Map<String, dynamic>)? _previousPaymentCallback;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(_calculateChange);
    // Check if payment is already completed (for online payments)
    if (_isOnlinePayment && widget.ride.paymentStatus == PaymentStatus.completed) {
      _paymentCompleted = true;
    }
    _setupPaymentListener();
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _removePaymentListener();
    super.dispose();
  }

  void _setupPaymentListener() {
    // Save previous callback to restore later
    _previousPaymentCallback = SocketService.onPaymentCompleted;
    
    // Listen for paymentCompleted event for this specific ride
    SocketService.onPaymentCompleted = (rideId, amount, paymentId, data) {
      // Call previous callback first (if exists) to maintain chain
      if (_previousPaymentCallback != null) {
        _previousPaymentCallback!(rideId, amount, paymentId, data);
      }
      
      // Handle paymentCompleted for this screen
      if (rideId == widget.ride.id && mounted) {
        print('💳 [CashCollectionScreen] Payment completed event received');
        print('   Ride ID: $rideId');
        print('   Amount: ₹$amount');
        print('   Payment ID: $paymentId');
        
        setState(() {
          _paymentCompleted = true;
          _paymentId = paymentId;
        });

        // Show success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💳 Payment completed: ₹${amount?.toStringAsFixed(2) ?? '0.00'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
  }

  void _removePaymentListener() {
    // Restore previous callback when screen is disposed
    SocketService.onPaymentCompleted = _previousPaymentCallback;
  }

  void _calculateChange() {
    final cashText = _cashReceivedController.text.trim();
    if (cashText.isEmpty) {
      setState(() {
        _changeAmount = null;
      });
      return;
    }

    final cash = double.tryParse(cashText);
    if (cash != null && cash >= 0) {
      setState(() {
        _changeAmount = cash > widget.ride.fare ? cash - widget.ride.fare : null;
      });
    } else {
      setState(() {
        _changeAmount = null;
      });
    }
  }

  Future<void> _confirmCollection() async {
    if (!mounted) return;

    try {
      // For CASH payments, mark as collected in backend
      if (_isCashPayment) {
        final driverId = await StorageService.getDriverId();
        if (driverId == null) {
          throw Exception('Driver ID not found');
        }

        print('💰 Marking cash as collected for ride: ${widget.ride.id}');
        await RideService.markCashCollected(
          driverId: driverId,
          rideId: widget.ride.id,
        );
        print('✅ Cash collection marked in database');
      }

      // Show success message based on payment method
      final message = _isCashPayment 
          ? '✅ Cash collection confirmed'
          : '✅ Payment information acknowledged';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Show rating dialog for the rider (for both cash and online payment)
      if (widget.ride.rider != null) {
        print('⭐ Showing rating dialog after payment collection');
        await showRatingDialog(
          context: context,
          rideId: widget.ride.id,
          riderId: widget.ride.rider!.id,
          riderName: widget.ride.rider!.fullName,
        );
      } else {
        print('⚠️ Rider info not available, skipping rating dialog');
      }

      // Navigate back to home
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('❌ Error marking cash as collected: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark cash as collected: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool get _isCashPayment => widget.ride.paymentMethod == PaymentMethod.cash;
  bool get _isOnlinePayment => widget.ride.paymentMethod == PaymentMethod.razorpay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Payment Collection'),
        backgroundColor: AppConstants.AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment method badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isCashPayment 
                      ? Colors.green.shade50 
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCashPayment 
                        ? Colors.green.shade200 
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCashPayment ? Icons.money : Icons.payment,
                      color: _isCashPayment 
                          ? Colors.green.shade700 
                          : Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCashPayment ? 'Cash Payment' : 'Online Payment',
                      style: TextStyle(
                        color: _isCashPayment 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Instructions - different for cash vs online
              Text(
                _isCashPayment
                    ? 'Please collect the following amount from the rider:'
                    : 'Rider will pay the following amount online in the app:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Fare amount display (large and prominent)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppConstants.AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppConstants.AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount to Collect',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${widget.ride.fare.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Rider information
              if (widget.ride.rider != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppConstants.AppColors.primary,
                        child: Text(
                          widget.ride.rider!.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ride.rider!.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.ride.rider!.phone != null)
                              Text(
                                widget.ride.rider!.phone!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Cash received input - only show for CASH payment
              if (_isCashPayment) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Calculate Change (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cashReceivedController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Cash Received (₹)',
                          hintText: 'Enter amount received',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      if (_changeAmount != null && _changeAmount! > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Change to Return: ₹${_changeAmount!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Online payment info - only show for RAZORPAY
              if (_isOnlinePayment) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _paymentCompleted 
                        ? Colors.green.shade50 
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _paymentCompleted 
                          ? Colors.green.shade200 
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _paymentCompleted ? Icons.check_circle : Icons.info_outline,
                        color: _paymentCompleted 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _paymentCompleted ? 'Payment Completed' : 'Payment Pending',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _paymentCompleted 
                              ? Colors.green.shade700 
                              : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _paymentCompleted
                            ? 'Payment has been successfully completed by the rider. You can proceed to rating.'
                            : 'The rider will complete payment in their app. You can proceed to rating after informing them.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_paymentCompleted && _paymentId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Payment ID: $_paymentId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Confirmation button
              ElevatedButton(
                onPressed: _confirmCollection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isCashPayment ? Icons.check_circle : Icons.done_all,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCashPayment 
                          ? 'Amount Collected'
                          : (_paymentCompleted 
                              ? 'Proceed to Rating'
                              : 'I\'ve Informed the Rider'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Help text
              Text(
                _isCashPayment
                    ? 'After collecting the cash, tap "Amount Collected" to proceed to rating.'
                    : 'After informing the rider about online payment, tap the button above to proceed to rating.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


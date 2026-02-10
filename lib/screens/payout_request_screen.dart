import 'package:flutter/material.dart';
import 'package:driver_cerca/models/payout_model.dart';
import 'package:driver_cerca/providers/payout_provider.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:provider/provider.dart';

/// PayoutRequestScreen for requesting payouts
class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  AccountType _accountType = AccountType.savings;
  String? _driverId;
  AvailableBalanceModel? _availableBalance;
  bool _useSavedBankAccount = false;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      await _loadAvailableBalance();
      await _loadBankAccount();
    }
  }

  Future<void> _loadAvailableBalance() async {
    try {
      final payoutProvider = Provider.of<PayoutProvider>(
        context,
        listen: false,
      );
      await payoutProvider.fetchAvailableBalance(_driverId!);
      setState(() {
        _availableBalance = payoutProvider.availableBalance;
        if (_availableBalance != null &&
            _availableBalance!.totalAvailable > 0) {
          _amountController.text = _availableBalance!.totalAvailable
              .toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading balance: $e')));
      }
    }
  }

  Future<void> _loadBankAccount() async {
    try {
      final payoutProvider = Provider.of<PayoutProvider>(
        context,
        listen: false,
      );
      await payoutProvider.fetchBankAccount(_driverId!);
      final bankAccount = payoutProvider.bankAccount;
      if (bankAccount != null) {
        setState(() {
          _useSavedBankAccount = true;
          _accountNumberController.text = bankAccount.accountNumber;
          _ifscCodeController.text = bankAccount.ifscCode;
          _accountHolderNameController.text = bankAccount.accountHolderName;
          _bankNameController.text = bankAccount.bankName;
          _accountType = bankAccount.accountType;
        });
      }
    } catch (e) {
      // Bank account might not exist, that's okay
    }
  }

  Future<void> _submitPayoutRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_driverId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver ID not found')));
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    if (_availableBalance != null) {
      if (amount > _availableBalance!.totalAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount exceeds available balance (₹${_availableBalance!.totalAvailable.toStringAsFixed(2)})',
            ),
          ),
        );
        return;
      }

      if (amount < _availableBalance!.minPayoutThreshold) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Minimum payout amount is ₹${_availableBalance!.minPayoutThreshold.toStringAsFixed(2)}',
            ),
          ),
        );
        return;
      }
    }

    final bankAccount = BankAccountModel(
      accountNumber: _accountNumberController.text.trim(),
      ifscCode: _ifscCodeController.text.trim(),
      accountHolderName: _accountHolderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountType: _accountType,
    );

    if (!bankAccount.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all bank account fields')),
      );
      return;
    }

    try {
      final payoutProvider = Provider.of<PayoutProvider>(
        context,
        listen: false,
      );
      await payoutProvider.requestPayout(
        driverId: _driverId!,
        amount: amount,
        bankAccount: bankAccount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request payout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Payout'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _availableBalance == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Available balance card
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_availableBalance!.totalAvailable.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (_availableBalance!.totalTips > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Including ₹${_availableBalance!.totalTips.toStringAsFixed(2)} in tips',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Minimum payout: ₹${_availableBalance!.minPayoutThreshold.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payout amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Payout Amount (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Invalid amount';
                        }
                        if (_availableBalance != null) {
                          if (amount > _availableBalance!.totalAvailable) {
                            return 'Amount exceeds available balance';
                          }
                          if (amount < _availableBalance!.minPayoutThreshold) {
                            return 'Minimum amount is ₹${_availableBalance!.minPayoutThreshold.toStringAsFixed(2)}';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bank account section
                    Row(
                      children: [
                        const Text(
                          'Bank Account Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_useSavedBankAccount)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _useSavedBankAccount = false;
                                _accountNumberController.clear();
                                _ifscCodeController.clear();
                                _accountHolderNameController.clear();
                                _bankNameController.clear();
                              });
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Account holder name
                    TextFormField(
                      controller: _accountHolderNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Account number
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // IFSC code
                    TextFormField(
                      controller: _ifscCodeController,
                      decoration: const InputDecoration(
                        labelText: 'IFSC Code',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Bank name
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Account type
                    DropdownButtonFormField<AccountType>(
                      value: _accountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                      ),
                      items: AccountType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _accountType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    Consumer<PayoutProvider>(
                      builder: (context, provider, _) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : _submitPayoutRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: provider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Request Payout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:driver_cerca/models/payout_model.dart';
import 'package:driver_cerca/providers/payout_provider.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:provider/provider.dart';

/// BankAccountScreen for viewing and editing bank account
class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  AccountType _accountType = AccountType.savings;
  String? _driverId;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      await _loadBankAccount();
    }
  }

  Future<void> _loadBankAccount() async {
    setState(() => _isLoading = true);
    try {
      final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
      await payoutProvider.fetchBankAccount(_driverId!);
      final bankAccount = payoutProvider.bankAccount;
      if (bankAccount != null) {
        setState(() {
          _accountNumberController.text = bankAccount.accountNumber;
          _ifscCodeController.text = bankAccount.ifscCode;
          _accountHolderNameController.text = bankAccount.accountHolderName;
          _bankNameController.text = bankAccount.bankName;
          _accountType = bankAccount.accountType;
          _isEditing = false;
        });
      } else {
        setState(() => _isEditing = true);
      }
    } catch (e) {
      setState(() => _isEditing = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBankAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID not found')),
      );
      return;
    }

    final bankAccount = BankAccountModel(
      accountNumber: _accountNumberController.text.trim(),
      ifscCode: _ifscCodeController.text.trim(),
      accountHolderName: _accountHolderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountType: _accountType,
    );

    try {
      final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
      await payoutProvider.updateBankAccount(
        driverId: _driverId!,
        bankAccount: bankAccount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bank account: $e'),
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
        title: const Text('Bank Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEditing && _accountNumberController.text.isNotEmpty) ...[
                      // View mode
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Account Holder', _accountHolderNameController.text),
                              const Divider(),
                              _buildInfoRow('Account Number', _accountNumberController.text),
                              const Divider(),
                              _buildInfoRow('IFSC Code', _ifscCodeController.text),
                              const Divider(),
                              _buildInfoRow('Bank Name', _bankNameController.text),
                              const Divider(),
                              _buildInfoRow('Account Type', _accountType.displayName),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Edit mode
                      TextFormField(
                        controller: _accountHolderNameController,
                        decoration: const InputDecoration(
                          labelText: 'Account Holder Name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accountNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ifscCodeController,
                        decoration: const InputDecoration(
                          labelText: 'IFSC Code',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
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
                        onChanged: _isEditing
                            ? (value) {
                                if (value != null) {
                                  setState(() => _accountType = value);
                                }
                              }
                            : null,
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _isEditing = false);
                                  _loadBankAccount(); // Reload to reset changes
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Consumer<PayoutProvider>(
                                builder: (context, provider, _) {
                                  return ElevatedButton(
                                    onPressed: provider.isLoading ? null : _saveBankAccount,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: provider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Save'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}


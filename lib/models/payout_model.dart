/// Payout models for driver payout management

/// Payout status enum
enum PayoutStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  final String value;
  const PayoutStatus(this.value);

  static PayoutStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PENDING':
        return PayoutStatus.pending;
      case 'PROCESSING':
        return PayoutStatus.processing;
      case 'COMPLETED':
        return PayoutStatus.completed;
      case 'FAILED':
        return PayoutStatus.failed;
      case 'CANCELLED':
        return PayoutStatus.cancelled;
      default:
        return PayoutStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PayoutStatus.pending:
        return 'Pending';
      case PayoutStatus.processing:
        return 'Processing';
      case PayoutStatus.completed:
        return 'Completed';
      case PayoutStatus.failed:
        return 'Failed';
      case PayoutStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Account type enum
enum AccountType {
  savings('SAVINGS'),
  current('CURRENT');

  final String value;
  const AccountType(this.value);

  static AccountType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'SAVINGS':
        return AccountType.savings;
      case 'CURRENT':
        return AccountType.current;
      default:
        return AccountType.savings;
    }
  }

  String get displayName {
    switch (this) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
    }
  }
}

/// Bank account model
class BankAccountModel {
  final String accountNumber;
  final String ifscCode;
  final String accountHolderName;
  final String bankName;
  final AccountType accountType;

  BankAccountModel({
    required this.accountNumber,
    required this.ifscCode,
    required this.accountHolderName,
    required this.bankName,
    this.accountType = AccountType.savings,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      accountNumber: json['accountNumber'] ?? '',
      ifscCode: json['ifscCode'] ?? '',
      accountHolderName: json['accountHolderName'] ?? '',
      bankName: json['bankName'] ?? '',
      accountType: AccountType.fromString(json['accountType']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountType': accountType.value,
    };
  }

  bool get isValid {
    return accountNumber.isNotEmpty &&
        ifscCode.isNotEmpty &&
        accountHolderName.isNotEmpty &&
        bankName.isNotEmpty;
  }
}

/// Available balance model
class AvailableBalanceModel {
  final double availableBalance;
  final double totalTips;
  final double totalAvailable;
  final double minPayoutThreshold;
  final bool canRequestPayout;
  final int unpaidRidesCount;

  AvailableBalanceModel({
    required this.availableBalance,
    required this.totalTips,
    required this.totalAvailable,
    required this.minPayoutThreshold,
    required this.canRequestPayout,
    required this.unpaidRidesCount,
  });

  factory AvailableBalanceModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return AvailableBalanceModel(
      availableBalance: (data['availableBalance'] ?? 0).toDouble(),
      totalTips: (data['totalTips'] ?? 0).toDouble(),
      totalAvailable: (data['totalAvailable'] ?? 0).toDouble(),
      minPayoutThreshold: (data['minPayoutThreshold'] ?? 500).toDouble(),
      canRequestPayout: data['canRequestPayout'] ?? false,
      unpaidRidesCount: data['unpaidRidesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'availableBalance': availableBalance,
      'totalTips': totalTips,
      'totalAvailable': totalAvailable,
      'minPayoutThreshold': minPayoutThreshold,
      'canRequestPayout': canRequestPayout,
      'unpaidRidesCount': unpaidRidesCount,
    };
  }
}

/// Payout model
class PayoutModel {
  final String id;
  final String driverId;
  final double amount;
  final BankAccountModel bankAccount;
  final PayoutStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? transactionId;
  final String? transactionReference;
  final String? failureReason;
  final String? notes;
  final Map<String, dynamic>? processedBy;

  PayoutModel({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.bankAccount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.transactionId,
    this.transactionReference,
    this.failureReason,
    this.notes,
    this.processedBy,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      driverId: json['driver']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      bankAccount: BankAccountModel.fromJson(json['bankAccount'] ?? {}),
      status: PayoutStatus.fromString(json['status']),
      requestedAt: json['requestedAt'] != null
          ? DateTime.parse(json['requestedAt'])
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'])
          : null,
      transactionId: json['transactionId'],
      transactionReference: json['transactionReference'],
      failureReason: json['failureReason'],
      notes: json['notes'],
      processedBy: json['processedBy'] is Map
          ? Map<String, dynamic>.from(json['processedBy'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'amount': amount,
      'bankAccount': bankAccount.toJson(),
      'status': status.value,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'transactionId': transactionId,
      'transactionReference': transactionReference,
      'failureReason': failureReason,
      'notes': notes,
    };
  }
}

/// Payout history response with pagination
class PayoutHistoryResponse {
  final List<PayoutModel> payouts;
  final PaginationInfo pagination;
  final PayoutStatistics statistics;

  PayoutHistoryResponse({
    required this.payouts,
    required this.pagination,
    required this.statistics,
  });

  factory PayoutHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return PayoutHistoryResponse(
      payouts:
          (data['payouts'] as List?)
              ?.map((p) => PayoutModel.fromJson(p))
              .toList() ??
          [],
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
      statistics: PayoutStatistics.fromJson(data['statistics'] ?? {}),
    );
  }
}

/// Pagination info
class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalPayouts;
  final int limit;

  PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalPayouts,
    required this.limit,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 0,
      totalPayouts: json['totalPayouts'] ?? 0,
      limit: json['limit'] ?? 20,
    );
  }
}

/// Payout statistics
class PayoutStatistics {
  final double totalPayoutAmount;
  final int totalPayouts;
  final double pendingAmount;
  final int pendingCount;

  PayoutStatistics({
    required this.totalPayoutAmount,
    required this.totalPayouts,
    required this.pendingAmount,
    required this.pendingCount,
  });

  factory PayoutStatistics.fromJson(Map<String, dynamic> json) {
    return PayoutStatistics(
      totalPayoutAmount: (json['totalPayoutAmount'] ?? 0).toDouble(),
      totalPayouts: json['totalPayouts'] ?? 0,
      pendingAmount: (json['pendingAmount'] ?? 0).toDouble(),
      pendingCount: json['pendingCount'] ?? 0,
    );
  }
}

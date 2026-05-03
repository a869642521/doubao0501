class CurrencyAccount {
  final String id;
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final DateTime? lastCheckIn;

  const CurrencyAccount({
    required this.id,
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    this.lastCheckIn,
  });

  factory CurrencyAccount.fromJson(Map<String, dynamic> json) {
    return CurrencyAccount(
      id: json['id'] as String,
      balance: json['balance'] as int? ?? 0,
      totalEarned: json['totalEarned'] as int? ?? 0,
      totalSpent: json['totalSpent'] as int? ?? 0,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'] as String)
          : null,
    );
  }

  bool get hasCheckedInToday {
    if (lastCheckIn == null) return false;
    final now = DateTime.now();
    return lastCheckIn!.year == now.year &&
        lastCheckIn!.month == now.month &&
        lastCheckIn!.day == now.day;
  }
}

class CurrencyTransaction {
  final String id;
  final int amount;
  final String type; // EARN or SPEND
  final String reason;
  final DateTime createdAt;

  const CurrencyTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.reason,
    required this.createdAt,
  });

  factory CurrencyTransaction.fromJson(Map<String, dynamic> json) {
    return CurrencyTransaction(
      id: json['id'] as String,
      amount: json['amount'] as int,
      type: json['type'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isEarn => type == 'EARN';
}

class SettlementRecord {
  final String id;
  final String friendId;
  final double amount;
  final DateTime date;

  SettlementRecord({
    required this.id,
    required this.friendId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'friendId': friendId,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory SettlementRecord.fromMap(Map<String, dynamic> map) {
    return SettlementRecord(
      id: map['id'] as String,
      friendId: map['friendId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }
}

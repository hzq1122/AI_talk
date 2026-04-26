class WalletTransaction {
  final String id;
  final double amount;
  final String type; // 'recharge' | 'spend'
  final String description;
  final String? contactId;
  final String? contactName;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.contactId,
    this.contactName,
    required this.createdAt,
  });

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'amount': amount,
        'type': type,
        'description': description,
        'contact_id': contactId,
        'contact_name': contactName,
        'created_at': createdAt.toIso8601String(),
      };

  factory WalletTransaction.fromDbMap(Map<String, dynamic> map) =>
      WalletTransaction(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: map['type'] as String,
        description: map['description'] as String,
        contactId: map['contact_id'] as String?,
        contactName: map['contact_name'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

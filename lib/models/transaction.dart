class Transaction {
  int? id;
  int userId;
  double totalAmount;
  double amountReceived;
  double change;
  String transactionDate;
  String dateCreated;
  String dateUpdated;

  Transaction({
    this.id,
    required this.userId,
    required this.totalAmount,
    required this.amountReceived,
    required this.change,
    required this.transactionDate,
    required this.dateCreated,
    required this.dateUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'total_amount': totalAmount,
      'amount_received': amountReceived,
      'change': change,
      'transaction_date': transactionDate,
      'date_created': dateCreated,
      'date_updated': dateUpdated,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      userId: (map['user_id'] as num).toInt(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountReceived: (map['amount_received'] as num).toDouble(),
      change: (map['change'] as num).toDouble(),
      transactionDate: map['transaction_date'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }

  Transaction copyWith({
    int? id,
    int? userId,
    double? totalAmount,
    double? amountReceived,
    double? change,
    String? transactionDate,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalAmount: totalAmount ?? this.totalAmount,
      amountReceived: amountReceived ?? this.amountReceived,
      change: change ?? this.change,
      transactionDate: transactionDate ?? this.transactionDate,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}

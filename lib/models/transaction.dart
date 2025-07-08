class Transaction {
  int? id;
  double totalAmount;
  double amountReceived;
  double change;
  String transactionDate;
  String dateCreated;
  String dateUpdated;

  Transaction({
    this.id,
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
      totalAmount: map['total_amount'],
      amountReceived: map['amount_received'],
      change: map['change'],
      transactionDate: map['transaction_date'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }
}
class Transaction {
  int? id;
  double totalAmount;
  String transactionDate;
  String dateCreated;
  String dateUpdated;

  Transaction({
    this.id,
    required this.totalAmount,
    required this.transactionDate,
    required this.dateCreated,
    required this.dateUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_amount': totalAmount,
      'transaction_date': transactionDate,
      'date_created': dateCreated,
      'date_updated': dateUpdated,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      totalAmount: map['total_amount'],
      transactionDate: map['transaction_date'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }
}
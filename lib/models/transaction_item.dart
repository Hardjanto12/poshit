class TransactionItem {
  int? id;
  int transactionId;
  int productId;
  int quantity;
  double priceAtTransaction;
  String dateCreated;
  String dateUpdated;

  TransactionItem({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.priceAtTransaction,
    required this.dateCreated,
    required this.dateUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_transaction': priceAtTransaction,
      'date_created': dateCreated,
      'date_updated': dateUpdated,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      priceAtTransaction: map['price_at_transaction'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }
}
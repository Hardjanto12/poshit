class Product {
  int? id;
  String name;
  double price;
  String? sku;
  int stockQuantity;
  String dateCreated;
  String dateUpdated;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.sku,
    this.stockQuantity = 0,
    required this.dateCreated,
    required this.dateUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'sku': sku,
      'stock_quantity': stockQuantity,
      'date_created': dateCreated,
      'date_updated': dateUpdated,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      sku: map['sku'],
      stockQuantity: map['stock_quantity'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }
}
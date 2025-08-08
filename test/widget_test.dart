// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'dart:io' show Platform;
import 'package:poshit/models/product.dart';

void main() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    // platform-specific code here
  }

  test('Product model toMap and fromMap', () {
    final product = Product(
      id: 1,
      userId: 1,
      name: 'Test',
      price: 100.0,
      sku: 'SKU1',
      stockQuantity: 10,
      dateCreated: '2024-01-01',
      dateUpdated: '2024-01-02',
    );
    final map = product.toMap();
    final fromMap = Product.fromMap(map);
    expect(fromMap.name, 'Test');
    expect(fromMap.price, 100.0);
    expect(fromMap.sku, 'SKU1');
    expect(fromMap.stockQuantity, 10);
  });
}

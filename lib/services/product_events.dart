import 'package:flutter/foundation.dart';

class ProductEvents {
  static final ProductEvents _instance = ProductEvents._internal();
  factory ProductEvents() => _instance;
  ProductEvents._internal();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void notifyUpdated() {
    version.value = version.value + 1;
  }
}

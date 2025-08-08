import 'package:poshit/models/product.dart';
import 'package:poshit/services/settings_service.dart';
import 'package:poshit/api/api_client.dart';

class ProductService {
  final ApiClient _api = ApiClient();
  final SettingsService _settingsService = SettingsService();

  Future<int> insertProduct(Product product) async {
    final productMap = Map<String, dynamic>.from(product.toMap());

    // Check if SKU is enabled
    final useSkuField = await _settingsService.getUseSkuField();

    // If SKU is disabled, set it to null before inserting
    if (!useSkuField) {
      productMap['sku'] = null;
    } else {
      // If SKU is enabled, treat empty string as null to avoid UNIQUE constraint violation
      if (productMap['sku'] == null || productMap['sku'].toString().isEmpty) {
        productMap['sku'] = null;
      }
    }

    final res = await _api.postJson('/products', productMap);
    return (res['id'] as num).toInt();
  }

  Future<List<Product>> getProducts() async {
    final list = await _api.getJsonList('/products');
    return list.map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Product?> getProductById(int id) async {
    try {
      final res = await _api.getJson('/products/$id');
      return Product.fromMap(res);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateProduct(Product product) async {
    final productMap = Map<String, dynamic>.from(product.toMap());

    // Check if SKU is enabled
    final useSkuField = await _settingsService.getUseSkuField();

    // If SKU is disabled, set it to null before updating
    if (!useSkuField) {
      productMap['sku'] = null;
    } else {
      // If SKU is enabled, treat empty string as null to avoid UNIQUE constraint violation
      if (productMap['sku'] == null || productMap['sku'].toString().isEmpty) {
        productMap['sku'] = null;
      }
    }

    final res = await _api.putJson('/products/${product.id}', productMap);
    return (res['id'] as num).toInt();
  }

  Future<int> deleteProduct(int id) async {
    await _api.delete('/products/$id');
    return 1;
  }

  Future<void> updateStockQuantity(int productId, int newQuantity) async {
    // Could be added to API if needed; for now fetch and update product
    final product = await getProductById(productId);
    if (product == null) return;
    final updated = Product(
      id: product.id,
      userId: product.userId,
      name: product.name,
      price: product.price,
      sku: product.sku,
      stockQuantity: newQuantity,
      dateCreated: product.dateCreated,
      dateUpdated: DateTime.now().toIso8601String(),
    );
    await updateProduct(updated);
  }

  Future<List<Product>> searchProducts(String query) async {
    final list = await _api.getJsonList(
      '/products/search',
      query: {'q': query},
    );
    return list.map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }
}

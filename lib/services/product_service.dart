import 'package:poshit/database_helper.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/services/settings_service.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SettingsService _settingsService = SettingsService();

  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    final productMap = Map<String, dynamic>.from(product.toMap());

    // Check if SKU is enabled
    final useSkuField = await _settingsService.getUseSkuField();

    // If SKU is disabled, set it to null before inserting
    if (!useSkuField) {
      productMap['sku'] = null;
    } else {
      // If SKU is enabled, treat empty string as null to avoid UNIQUE constraint violation
      if (productMap['sku'] == null ||
          (productMap['sku'] is String &&
              (productMap['sku'] as String).trim().isEmpty)) {
        productMap['sku'] = null;
      }
    }

    return await db.insert('products', productMap);
  }

  Future<List<Product>> getProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    final productMap = Map<String, dynamic>.from(product.toMap());

    // Check if SKU is enabled
    final useSkuField = await _settingsService.getUseSkuField();

    // If SKU is disabled, set it to null before updating
    if (!useSkuField) {
      productMap['sku'] = null;
    } else {
      // If SKU is enabled, treat empty string as null to avoid UNIQUE constraint violation
      if (productMap['sku'] == null ||
          (productMap['sku'] is String &&
              (productMap['sku'] as String).trim().isEmpty)) {
        productMap['sku'] = null;
      }
    }

    return await db.update(
      'products',
      productMap,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  /// Returns true if SKU is unique or SKU is disabled or SKU is null/empty.
  Future<bool> isSkuUnique(String? sku, [int? excludeId]) async {
    final useSkuField = await _settingsService.getUseSkuField();

    if (!useSkuField || sku == null || sku.trim().isEmpty) {
      // If SKU is disabled or not provided, always return true
      return true;
    }
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'sku = ?${excludeId != null ? ' AND id != ?' : ''}',
      whereArgs: excludeId != null ? [sku, excludeId] : [sku],
    );
    return result.isEmpty;
  }
}

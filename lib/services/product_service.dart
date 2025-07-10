import 'package:poshit/database_helper.dart';
import 'package:poshit/models/product.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// If [enableSku] is false, SKU will be ignored (not checked for uniqueness).
  bool enableSku = true;

  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    final productMap = Map<String, dynamic>.from(product.toMap());

    // If SKU is disabled, set it to null before inserting
    if (!enableSku) {
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

    // If SKU is disabled, set it to null before updating
    if (!enableSku) {
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
    if (!enableSku || sku == null || sku.trim().isEmpty) {
      // If SKU is disabled or not provided, always return true
      return true;
    }
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'sku = ?' + (excludeId != null ? ' AND id != ?' : ''),
      whereArgs: excludeId != null ? [sku, excludeId] : [sku],
    );
    return result.isEmpty;
  }
}

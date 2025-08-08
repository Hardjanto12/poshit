import 'package:poshit/database_helper.dart';
import 'package:poshit/models/product.dart';
import 'package:poshit/services/settings_service.dart';
import 'package:poshit/services/user_session_service.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SettingsService _settingsService = SettingsService();
  final UserSessionService _userSessionService = UserSessionService();

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
      if (productMap['sku'] == null || productMap['sku'].toString().isEmpty) {
        productMap['sku'] = null;
      }
    }

    return await db.insert('products', productMap);
  }

  Future<List<Product>> getProducts() async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    } else {
      return null;
    }
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
      if (productMap['sku'] == null || productMap['sku'].toString().isEmpty) {
        productMap['sku'] = null;
      }
    }

    return await db.update(
      'products',
      productMap,
      where: 'id = ? AND user_id = ?',
      whereArgs: [product.id, product.userId],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return 0;

    return await db.delete(
      'products',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> updateStockQuantity(int productId, int newQuantity) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return;

    await db.update(
      'products',
      {
        'stock_quantity': newQuantity,
        'date_updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [productId, userId],
    );
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'user_id = ? AND (name LIKE ? OR sku LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }
}

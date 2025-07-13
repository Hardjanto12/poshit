import 'package:poshit/database_helper.dart';
import 'package:poshit/models/transaction.dart' as poshit_txn;
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/models/product.dart'; // Import Product model
import 'package:poshit/services/product_service.dart'; // Import ProductService
import 'package:poshit/services/settings_service.dart'; // Import SettingsService
import 'package:poshit/services/user_session_service.dart'; // Import UserSessionService

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProductService _productService =
      ProductService(); // Instantiate ProductService
  final SettingsService _settingsService =
      SettingsService(); // Instantiate SettingsService
  final UserSessionService _userSessionService =
      UserSessionService(); // Instantiate UserSessionService

  Future<int> insertTransaction(
    poshit_txn.Transaction transaction,
    List<TransactionItem> items,
  ) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // Check settings outside the transaction to avoid database locks
    final useInventoryTracking = await _settingsService
        .getUseInventoryTracking();

    // Start a transaction
    return await db.transaction((txn) async {
      // Insert the transaction
      final transactionId = await txn.insert(
        'transactions',
        transaction.toMap(),
      );

      // Insert transaction items
      for (final item in items) {
        final itemMap = Map<String, dynamic>.from(item.toMap());
        itemMap['transaction_id'] = transactionId;
        await txn.insert('transaction_items', itemMap);

        // Update product stock quantity if inventory tracking is enabled
        if (useInventoryTracking) {
          // Get product using the transaction object
          final List<Map<String, dynamic>> productMaps = await txn.query(
            'products',
            where: 'id = ? AND user_id = ?',
            whereArgs: [item.productId, userId],
          );

          if (productMaps.isNotEmpty) {
            final product = productMaps.first;
            final currentStock = product['stock_quantity'] as int;
            final newStockQuantity = currentStock - item.quantity;

            // Update stock using the transaction object
            await txn.update(
              'products',
              {
                'stock_quantity': newStockQuantity,
                'date_updated': DateTime.now().toIso8601String(),
              },
              where: 'id = ? AND user_id = ?',
              whereArgs: [item.productId, userId],
            );
          }
        }
      }

      return transactionId; // Return the actual transaction ID
    });
  }

  Future<List<poshit_txn.Transaction>> getTransactions() async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'transaction_date DESC',
    );
    return List.generate(maps.length, (i) {
      return poshit_txn.Transaction.fromMap(maps[i]);
    });
  }

  Future<poshit_txn.Transaction?> getTransactionById(int id) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (maps.isNotEmpty) {
      return poshit_txn.Transaction.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];

    // First verify the transaction belongs to the current user
    final transaction = await getTransactionById(transactionId);
    if (transaction == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return List.generate(maps.length, (i) {
      return TransactionItem.fromMap(maps[i]);
    });
  }

  Future<int> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    final userId = _userSessionService.currentUserId;
    if (userId == null) return 0;

    return await db.delete(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) {
      return {
        'totalRevenue': 0.0,
        'totalTransactions': 0,
        'averageSaleValue': 0.0,
      };
    }
    return await _dbHelper.getTodaySummary(userId);
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts() async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];
    return await _dbHelper.getTopSellingProducts(userId);
  }
}

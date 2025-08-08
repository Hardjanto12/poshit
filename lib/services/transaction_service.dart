import 'package:poshit/models/transaction.dart' as poshit_txn;
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/services/settings_service.dart'; // Import SettingsService
import 'package:poshit/services/user_session_service.dart'; // Import UserSessionService
import 'package:poshit/api/api_client.dart';

class TransactionService {
  final ApiClient _api = ApiClient();
  final SettingsService _settingsService =
      SettingsService(); // Instantiate SettingsService
  final UserSessionService _userSessionService =
      UserSessionService(); // Instantiate UserSessionService

  Future<int> insertTransaction(
    poshit_txn.Transaction transaction,
    List<TransactionItem> items,
  ) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // Check settings outside the transaction to avoid database locks
    final useInventoryTracking = await _settingsService
        .getUseInventoryTracking();

    // Compose payload for backend create transaction
    final payload = {
      ...transaction.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      // Backend already updates stock; we still honor setting for client-side future use
      'use_inventory_tracking': useInventoryTracking,
    };
    final res = await _api.postJson('/transactions', payload);
    return (res['id'] as num).toInt();
  }

  Future<List<poshit_txn.Transaction>> getTransactions() async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];
    final list = await _api.getJsonList('/transactions');
    return list
        .map((e) => poshit_txn.Transaction.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<poshit_txn.Transaction?> getTransactionById(int id) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return null;
    try {
      final res = await _api.getJson('/transactions/$id');
      return poshit_txn.Transaction.fromMap(res);
    } catch (_) {
      return null;
    }
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];

    // First verify the transaction belongs to the current user
    final transaction = await getTransactionById(transactionId);
    if (transaction == null) return [];

    final list = await _api.getJsonList('/transactions/$transactionId/items');
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return TransactionItem(
        id: map['id'],
        transactionId: map['transaction_id'],
        productId: map['product_id'],
        quantity: map['quantity'],
        priceAtTransaction: map['price_at_transaction'],
        productName: map['product_name'],
        dateCreated: map['date_created'],
        dateUpdated: map['date_updated'],
      );
    }).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return 0;
    await _api.delete('/transactions/$id');
    return 1;
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
    final res = await _api.getJson('/analytics/today-summary');
    return res;
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts() async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return [];
    final list = await _api.getJsonList('/analytics/top-selling');
    return list.cast<Map<String, dynamic>>();
  }
}

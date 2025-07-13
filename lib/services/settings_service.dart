import 'package:shared_preferences/shared_preferences.dart';
import 'package:poshit/database_helper.dart';
import 'package:poshit/services/user_session_service.dart';
import 'package:sqflite/sqflite.dart';

class SettingsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final UserSessionService _userSessionService = UserSessionService();

  Future<void> setPrinterType(String printerType) async {
    await _setSetting('printer_type', printerType);
  }

  Future<String> getPrinterType() async {
    return await _getSetting('printer_type', 'Bluetooth');
  }

  Future<void> setBusinessName(String businessName) async {
    await _setSetting('business_name', businessName);
  }

  Future<String> getBusinessName() async {
    return await _getSetting('business_name', 'My Business');
  }

  Future<void> setReceiptFooter(String receiptFooter) async {
    await _setSetting('receipt_footer', receiptFooter);
  }

  Future<String> getReceiptFooter() async {
    return await _getSetting('receipt_footer', 'Thank you for your purchase!');
  }

  Future<void> setUseInventoryTracking(bool useInventoryTracking) async {
    await _setSetting(
      'use_inventory_tracking',
      useInventoryTracking.toString(),
    );
  }

  Future<bool> getUseInventoryTracking() async {
    final value = await _getSetting('use_inventory_tracking', 'true');
    return value.toLowerCase() == 'true';
  }

  Future<void> setUseSkuField(bool useSkuField) async {
    await _setSetting('use_sku_field', useSkuField.toString());
  }

  Future<bool> getUseSkuField() async {
    final value = await _getSetting('use_sku_field', 'true');
    return value.toLowerCase() == 'true';
  }

  Future<void> setLastConnectedPrinterAddress(String address) async {
    await _setSetting('last_connected_printer_address', address);
  }

  Future<String?> getLastConnectedPrinterAddress() async {
    return await _getSettingNullable('last_connected_printer_address', null);
  }

  Future<void> _setSetting(String key, String value) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return;

    final db = await _dbHelper.database;
    await db.insert('settings', {
      'user_id': userId,
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _getSetting(String key, String defaultValue) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return defaultValue;

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    } else {
      // Set default value if not found
      await _setSetting(key, defaultValue);
      return defaultValue;
    }
  }

  Future<String?> _getSettingNullable(String key, String? defaultValue) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return defaultValue;

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    } else {
      // Set default value if not found and default is not null
      if (defaultValue != null) {
        await _setSetting(key, defaultValue);
      }
      return defaultValue;
    }
  }
}

import 'package:poshit/services/user_session_service.dart';
import 'package:poshit/api/api_client.dart';

class SettingsService {
  final UserSessionService _userSessionService = UserSessionService();
  final ApiClient _api = ApiClient();

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
    await _api.putJson('/settings/$key', {'value': value});
  }

  Future<String> _getSetting(String key, String defaultValue) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return defaultValue;
    try {
      final res = await _api.getJson('/settings/$key');
      final value = res['value'];
      if (value == null) {
        await _setSetting(key, defaultValue);
        return defaultValue;
      }
      return value as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<String?> _getSettingNullable(String key, String? defaultValue) async {
    final userId = _userSessionService.currentUserId;
    if (userId == null) return defaultValue;
    try {
      final res = await _api.getJson('/settings/$key');
      final value = res['value'];
      if (value == null) {
        if (defaultValue != null) {
          await _setSetting(key, defaultValue);
        }
        return defaultValue;
      }
      return value as String;
    } catch (_) {
      return defaultValue;
    }
  }
}

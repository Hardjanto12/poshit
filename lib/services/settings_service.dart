import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _printerTypeKey = 'printerType';
  static const String _lastConnectedPrinterAddressKey = 'lastConnectedPrinterAddress';
  static const String _useInventoryTrackingKey = 'useInventoryTracking';
  static const String _useSkuFieldKey = 'useSkuField';
  static const String _businessNameKey = 'businessName';
  static const String _receiptFooterKey = 'receiptFooter';

  Future<String> getPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerTypeKey) ?? 'Bluetooth'; // Default to Bluetooth
  }

  Future<void> setPrinterType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerTypeKey, type);
  }

  Future<String?> getLastConnectedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectedPrinterAddressKey);
  }

  Future<void> setLastConnectedPrinterAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConnectedPrinterAddressKey, address);
  }

  Future<bool> getUseInventoryTracking() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useInventoryTrackingKey) ?? true; // Default to true
  }

  Future<void> setUseInventoryTracking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useInventoryTrackingKey, value);
  }

  Future<bool> getUseSkuField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSkuFieldKey) ?? true; // Default to true
  }

  Future<void> setUseSkuField(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSkuFieldKey, value);
  }

  Future<String> getBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_businessNameKey) ?? 'My Store'; // Default to 'My Store'
  }

  Future<void> setBusinessName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessNameKey, name);
  }

  Future<String> getReceiptFooter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_receiptFooterKey) ?? 'Thank you!'; // Default to 'Thank you!'
  }

  Future<void> setReceiptFooter(String footer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptFooterKey, footer);
  }
}

import 'package:flutter/foundation.dart';

import 'bluetooth_printer_android.dart' if (dart.library.io) 'bluetooth_printer_windows.dart';

abstract class BluetoothPrinter {
  Stream<List<BluetoothDevice>> get scanResults;
  Stream<bool> get isScanning;
  Stream<BluetoothPrintConnectionStatus> get connectionStatus;
  bool get isConnected;

  Future<void> startScan({Duration timeout = const Duration(seconds: 4)});
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device);
  Future<void> disconnect();
  Future<void> write(Uint8List data);
}

// This is the actual implementation that will be used based on the import condition
BluetoothPrinter get bluetoothPrinter => getBluetoothPrinter();

// Define common classes used by both implementations
class BluetoothDevice {
  final String? name;
  final String? address;
  final int? type;
  final bool? connected;

  BluetoothDevice(this.name, this.address, {this.type, this.connected});
}

enum BluetoothPrintConnectionStatus {
  connected,
  connecting,
  disconnected,
  disconnecting,
  unknown,
}

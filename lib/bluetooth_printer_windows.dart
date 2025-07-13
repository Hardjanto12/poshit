import 'dart:typed_data';

import 'bluetooth_printer.dart';

BluetoothPrinter getBluetoothPrinter() => _BluetoothPrinterWindows();

class _BluetoothPrinterWindows implements BluetoothPrinter {
  @override
  Stream<List<BluetoothDevice>> get scanResults => Stream.value([]);

  @override
  Stream<bool> get isScanning => Stream.value(false);

  @override
  Stream<BluetoothPrintConnectionStatus> get connectionStatus =>
      Stream.value(BluetoothPrintConnectionStatus.disconnected);

  @override
  bool get isConnected => false;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 4)}) async {
    // Not supported on Windows
  }

  @override
  Future<void> stopScan() async {
    // Not supported on Windows
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    // Not supported on Windows
  }

  @override
  Future<void> disconnect() async {
    // Not supported on Windows
  }

  @override
  Future<void> write(Uint8List data) async {
    // Not supported on Windows
  }
}

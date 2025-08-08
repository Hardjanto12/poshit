import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart' as bpp;

import 'bluetooth_printer.dart';

BluetoothPrinter getBluetoothPrinter() => _BluetoothPrinterAndroid();

class _BluetoothPrinterAndroid implements BluetoothPrinter {
  @override
  Stream<List<BluetoothDevice>> get scanResults =>
      bpp.BluetoothPrintPlus.scanResults.map(
        (devices) => devices
            .map(
              (d) =>
                  BluetoothDevice(d.name ?? '', d.address ?? '', type: d.type),
            )
            .toList(),
      );

  @override
  Stream<bool> get isScanning => bpp.BluetoothPrintPlus.isScanning;

  @override
  Stream<BluetoothPrintConnectionStatus> get connectionStatus =>
      bpp.BluetoothPrintPlus.connectState.map((status) {
        switch (status) {
          case 'connected':
            return BluetoothPrintConnectionStatus.connected;
          case 'connecting':
            return BluetoothPrintConnectionStatus.connecting;
          case 'disconnected':
            return BluetoothPrintConnectionStatus.disconnected;
          case 'disconnecting':
            return BluetoothPrintConnectionStatus.disconnecting;
          default:
            return BluetoothPrintConnectionStatus.unknown;
        }
      });

  @override
  bool get isConnected => bpp.BluetoothPrintPlus.isConnected;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 4)}) =>
      bpp.BluetoothPrintPlus.startScan(timeout: timeout);

  @override
  Future<void> stopScan() => bpp.BluetoothPrintPlus.stopScan();

  @override
  Future<void> connect(BluetoothDevice device) {
    // Find the original device from scan results to pass to the package
    return bpp.BluetoothPrintPlus.scanResults.first.then((devices) {
      final originalDevice = devices.firstWhere(
        (d) => d.address == device.address,
        orElse: () => throw Exception('Device not found in scan results'),
      );
      return bpp.BluetoothPrintPlus.connect(originalDevice);
    });
  }

  @override
  Future<void> disconnect() => bpp.BluetoothPrintPlus.disconnect();

  @override
  Future<void> write(Uint8List data) => bpp.BluetoothPrintPlus.write(data);
}

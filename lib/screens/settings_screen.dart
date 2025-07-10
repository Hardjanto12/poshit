import 'package:flutter/material.dart';
import 'package:poshit/services/settings_service.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:bluetooth_print_plus/bluetooth_print_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  String _selectedPrinterType = 'Bluetooth';
  late TextEditingController _businessNameController;
  late TextEditingController _receiptFooterController;
  bool _useInventoryTracking = true;
  bool _useSkuField = true;

  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  String? _lastConnectedPrinterAddress;


  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _receiptFooterController = TextEditingController();
    _loadSettings();

    bluetoothPrint.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
    });

    bluetoothPrint.isScanning.listen((isScanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = isScanning;
      });
    });

    bluetoothPrint.connectionStatus.listen((status) {
      if (!mounted) return;
      if (status == BluetoothPrintConnectionStatus.connected) {
        _loadLastConnectedPrinterAddress(); // Reload to update _connectedDevice
      } else {
        setState(() {
          _connectedDevice = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _receiptFooterController.dispose();
    bluetoothPrint.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      await bluetoothPrint.stopScan();
    }
    await bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    if (_connectedDevice != null && _connectedDevice!.address == device.address) {
      // Already connected to this device
      return;
    }

    await bluetoothPrint.disconnect();
    await bluetoothPrint.connect(device);
    if (bluetoothPrint.state == BluetoothPrintConnectionStatus.connected) {
      await _settingsService.setLastConnectedPrinterAddress(device.address!);
      setState(() {
        _connectedDevice = device;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name ?? device.address}')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to ${device.name ?? device.address}')),
        );
      }
    }
  }

  Future<void> _loadLastConnectedPrinterAddress() async {
    _lastConnectedPrinterAddress = await _settingsService.getLastConnectedPrinterAddress();
    if (_lastConnectedPrinterAddress != null) {
      // Attempt to reconnect to the last connected printer
      // This might not immediately update _connectedDevice if the device is not in range
      // or Bluetooth is off. The connectionStatus listener will handle the actual state.
      setState(() {
        _connectedDevice = BluetoothDevice(address: _lastConnectedPrinterAddress);
      });
    }
  }

  Future<void> _saveSettings() async {
    await _settingsService.setPrinterType(_selectedPrinterType);
    await _settingsService.setBusinessName(_businessNameController.text);
    await _settingsService.setReceiptFooter(_receiptFooterController.text);
    await _settingsService.setUseInventoryTracking(_useInventoryTracking);
    await _settingsService.setUseSkuField(_useSkuField);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  Future<void> _loadSettings() async {
    _selectedPrinterType = await _settingsService.getPrinterType();
    _businessNameController.text = await _settingsService.getBusinessName();
    _receiptFooterController.text = await _settingsService.getReceiptFooter();
    _useInventoryTracking = await _settingsService.getUseInventoryTracking();
    _useSkuField = await _settingsService.getUseSkuField();
    _lastConnectedPrinterAddress = await _settingsService.getLastConnectedPrinterAddress();

    if (_lastConnectedPrinterAddress != null) {
      // Attempt to connect to the last used printer on startup
      // This will trigger the connectionStatus listener to update _connectedDevice
      bluetoothPrint.connect(BluetoothDevice(address: _lastConnectedPrinterAddress));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Printer Type Selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Select Printer Type',
              ),
              value: _selectedPrinterType,
              items: const [
                DropdownMenuItem(
                  value: 'Bluetooth',
                  child: Text('Bluetooth Printer'),
                ),
                DropdownMenuItem(
                  value: 'System Printer',
                  child: Text('System Printer (USB/Wired)'),
                ),
              ],
              onChanged: (type) {
                if (type != null) {
                  setState(() {
                    _selectedPrinterType = type;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            // Bluetooth Printer Settings
            if (_selectedPrinterType == 'Bluetooth') ...[
              const Text(
                'Bluetooth Printer Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isScanning ? null : _startScan,
                      child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _connectedDevice != null
                          ? () async {
                              await bluetoothPrint.disconnect();
                              setState(() {
                                _connectedDevice = null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Printer disconnected.')),
                              );
                            }
                          : null,
                      child: const Text('Disconnect Printer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Connected Device: ${_connectedDevice?.name ?? 'None'}'),
              const SizedBox(height: 10),
              const Text('Available Devices:'),
              _devices.isEmpty
                  ? const Text('No devices found. Scan to find printers.')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return ListTile(
                          title: Text(device.name ?? 'Unknown Device'),
                          subtitle: Text(device.address ?? ''),
                          trailing: _connectedDevice?.address == device.address
                              ? const Icon(Icons.check, color: Colors.green)
                              : ElevatedButton(
                                  onPressed: () => _connectDevice(device),
                                  child: const Text('Connect'),
                                ),
                        );
                      },
                    ),
              const SizedBox(height: 20),
            ],
            // Business Name
            TextField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Business Name',
              ),
              onChanged: (value) => _saveSettings(), // Save on change
            ),
            const SizedBox(height: 20),
            // Receipt Footer Note
            TextField(
              controller: _receiptFooterController,
              decoration: const InputDecoration(
                labelText: 'Receipt Footer Note',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _saveSettings(), // Save on change
            ),
            const SizedBox(height: 20),
            // Enable Inventory Tracking
            SwitchListTile(
              title: const Text('Enable Inventory Tracking'),
              value: _useInventoryTracking,
              onChanged: (value) {
                setState(() {
                  _useInventoryTracking = value;
                });
                _saveSettings(); // Save on change
              },
            ),
            const SizedBox(height: 10),
            // Enable Product SKUs
            SwitchListTile(
              title: const Text('Enable Product SKUs'),
              value: _useSkuField,
              onChanged: (value) {
                setState(() {
                  _useSkuField = value;
                });
                _saveSettings(); // Save on change
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

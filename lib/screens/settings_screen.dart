import 'package:flutter/material.dart';
import 'package:poshit/services/settings_service.dart';
import 'package:poshit/bluetooth_printer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  // Current values (what user sees and can modify)
  String _selectedPrinterType = 'Bluetooth';
  late TextEditingController _businessNameController;
  late TextEditingController _receiptFooterController;
  bool _useInventoryTracking = true;
  bool _useSkuField = true;

  // Original values (to detect changes)
  String _originalPrinterType = 'Bluetooth';
  String _originalBusinessName = '';
  String _originalReceiptFooter = '';
  bool _originalUseInventoryTracking = true;
  bool _originalUseSkuField = true;

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

    bluetoothPrinter.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
    });

    bluetoothPrinter.isScanning.listen((isScanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = isScanning;
      });
    });

    bluetoothPrinter.connectionStatus.listen((status) {
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
    bluetoothPrinter.stopScan();
    super.dispose();
  }

  // Check if any settings have been modified
  bool get _hasUnsavedChanges {
    return _selectedPrinterType != _originalPrinterType ||
        _businessNameController.text != _originalBusinessName ||
        _receiptFooterController.text != _originalReceiptFooter ||
        _useInventoryTracking != _originalUseInventoryTracking ||
        _useSkuField != _originalUseSkuField;
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      await bluetoothPrinter.stopScan();
    }
    await bluetoothPrinter.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    if (_connectedDevice != null &&
        _connectedDevice!.address == device.address) {
      // Already connected to this device
      return;
    }

    await bluetoothPrinter.disconnect();
    await bluetoothPrinter.connect(device);
    if (bluetoothPrinter.isConnected) {
      await _settingsService.setLastConnectedPrinterAddress(device.address!);
      setState(() {
        _connectedDevice = device;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name ?? device.address}'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to connect to ${device.name ?? device.address}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadLastConnectedPrinterAddress() async {
    _lastConnectedPrinterAddress = await _settingsService
        .getLastConnectedPrinterAddress();
    if (_lastConnectedPrinterAddress != null) {
      // Attempt to reconnect to the last connected printer
      // This might not immediately update _connectedDevice if the device is not in range
      // or Bluetooth is off. The connectionStatus listener will handle the actual state.
      setState(() {
        _connectedDevice = BluetoothDevice('', _lastConnectedPrinterAddress!);
      });
    }
  }

  Future<void> _saveSettings() async {
    await _settingsService.setPrinterType(_selectedPrinterType);
    await _settingsService.setBusinessName(_businessNameController.text);
    await _settingsService.setReceiptFooter(_receiptFooterController.text);
    await _settingsService.setUseInventoryTracking(_useInventoryTracking);
    await _settingsService.setUseSkuField(_useSkuField);

    // Update original values after successful save
    _originalPrinterType = _selectedPrinterType;
    _originalBusinessName = _businessNameController.text;
    _originalReceiptFooter = _receiptFooterController.text;
    _originalUseInventoryTracking = _useInventoryTracking;
    _originalUseSkuField = _useSkuField;

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
    _lastConnectedPrinterAddress = await _settingsService
        .getLastConnectedPrinterAddress();

    // Store original values
    _originalPrinterType = _selectedPrinterType;
    _originalBusinessName = _businessNameController.text;
    _originalReceiptFooter = _receiptFooterController.text;
    _originalUseInventoryTracking = _useInventoryTracking;
    _originalUseSkuField = _useSkuField;

    if (_lastConnectedPrinterAddress != null) {
      // Attempt to connect to the last used printer on startup
      // This will trigger the connectionStatus listener to update _connectedDevice
      bluetoothPrinter.connect(
        BluetoothDevice('', _lastConnectedPrinterAddress!),
      );
    }
    setState(() {});
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true; // Allow exit if no changes
    }

    // Show confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Do you want to save them before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Discard changes
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true); // Save changes
                await _saveSettings();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return false; // Cancel - stay on screen
    } else if (result == true) {
      return true; // Save and exit
    } else {
      return true; // Discard and exit
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
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
                        child: Text(
                          _isScanning ? 'Scanning...' : 'Scan for Devices',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _connectedDevice != null
                            ? () async {
                                await bluetoothPrinter.disconnect();
                                setState(() {
                                  _connectedDevice = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Printer disconnected.'),
                                  ),
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
                            trailing:
                                _connectedDevice?.address == device.address
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
                // Removed onChanged to prevent auto-saving
              ),
              const SizedBox(height: 20),
              // Receipt Footer Note
              TextField(
                controller: _receiptFooterController,
                decoration: const InputDecoration(
                  labelText: 'Receipt Footer Note',
                  border: OutlineInputBorder(),
                ),
                // Removed onChanged to prevent auto-saving
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
                  // Removed _saveSettings() to prevent auto-saving
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
                  // Removed _saveSettings() to prevent auto-saving
                },
              ),
              const SizedBox(height: 20),
              // Save Changes Button
              ElevatedButton(
                onPressed: _hasUnsavedChanges ? _saveSettings : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasUnsavedChanges
                      ? Colors.blue
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  _hasUnsavedChanges ? 'Save Changes' : 'No Changes to Save',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (_hasUnsavedChanges) ...[
                const SizedBox(height: 10),
                const Text(
                  'You have unsaved changes. Please save before leaving.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

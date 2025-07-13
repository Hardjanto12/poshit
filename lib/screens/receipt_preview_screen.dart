import 'package:flutter/material.dart';
import 'package:poshit/models/transaction.dart';
import 'package:poshit/models/transaction_item.dart';
import 'package:poshit/utils/currency_formatter.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:poshit/services/settings_service.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final Transaction transaction;
  final List<TransactionItem> transactionItems;
  final double cashReceived;
  final double changeGiven;

  const ReceiptPreviewScreen({
    super.key,
    required this.transaction,
    required this.transactionItems,
    required this.cashReceived,
    required this.changeGiven,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final SettingsService _settingsService = SettingsService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  String _selectedPrinterType = 'Bluetooth'; // Default to Bluetooth

  String _businessName = 'My Store';
  String _receiptFooter = 'Thank you!';

  // BluetoothPrintPlus.isConnected is a bool, not a ValueNotifier
  bool get _connected => BluetoothPrintPlus.isConnected;

  @override
  void initState() {
    super.initState();
    _loadPrinterType();
    _initBluetooth(); // Call _initBluetooth to start scanning and attempt auto-connect
    _loadSettings();
    BluetoothPrintPlus.connectState.listen((state) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when dependencies change (e.g., when screen is opened)
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final businessName = await _settingsService.getBusinessName();
    final receiptFooter = await _settingsService.getReceiptFooter();
    if (mounted) {
      setState(() {
        _businessName = businessName;
        _receiptFooter = receiptFooter;
      });
    }
  }

  Future<void> _loadPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedPrinterType = prefs.getString('printerType') ?? 'Bluetooth';
    });
  }

  Future<void> _savePrinterType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerType', type);
  }

  Future<void> _initBluetooth() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAddress = prefs.getString('lastConnectedPrinterAddress');

    BluetoothPrintPlus.scanResults.listen((devices) async {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
      if (lastAddress != null && _device == null) {
        // Only try to auto-connect if no device is currently selected
        final deviceToConnect = devices.firstWhereOrNull(
          (d) => d.address == lastAddress,
        );
        if (deviceToConnect != null) {
          setState(() {
            _device = deviceToConnect; // Set the device for UI
          });
          await _connect(); // Attempt to connect
        }
      }
    });

    BluetoothPrintPlus.connectState.listen((state) {
      if (mounted) setState(() {});
    });

    await BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> _connect() async {
    if (_device == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No device selected')));
      return;
    }
    try {
      await BluetoothPrintPlus.connect(
        _device!,
      ); // _device is checked for null above

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to ${_device?.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
    }
  }

  Future<void> _disconnect() async {
    try {
      await BluetoothPrintPlus.disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disconnected')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to disconnect: $e')));
    }
  }

  double _getItemTotal(TransactionItem item) {
    return item.priceAtTransaction * item.quantity;
  }

  Future<void> _printReceipt() async {
    if (!_connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to a Bluetooth printer first.'),
        ),
      );
      return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text(
      _businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      "--------------------------------",
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      "Transaction ID: ${widget.transaction.id}",
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.text(
      "Date: ${widget.transaction.transactionDate}",
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.text(
      "--------------------------------",
      styles: const PosStyles(align: PosAlign.center),
    );

    for (var item in widget.transactionItems) {
      bytes += generator.text(
        "${item.productName} x ${item.quantity}",
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        formatToIDR(_getItemTotal(item)),
        styles: const PosStyles(align: PosAlign.right),
      );
    }
    bytes += generator.text(
      "--------------------------------",
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      "Subtotal: ${formatToIDR(widget.transaction.totalAmount)}",
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      "Discount: ${formatToIDR(0)}",
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      "Total: ${formatToIDR(widget.transaction.totalAmount)}",
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      "Cash Received: ${formatToIDR(widget.cashReceived)}",
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      "Change: ${formatToIDR(widget.changeGiven)}",
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      "--------------------------------",
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      _receiptFooter,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(4);
    bytes += generator.cut();

    await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
  }

  Future<void> _generateAndSavePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  _businessName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Transaction ID: ${widget.transaction.id}"),
              pw.Text("Date: ${widget.transaction.transactionDate}"),
              pw.Divider(),
              pw.Text(
                "Items:",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              ...widget.transactionItems.map(
                (item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("${item.productName} x ${item.quantity}"),
                    pw.Text(formatToIDR(_getItemTotal(item))),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Subtotal:"),
                  pw.Text(formatToIDR(widget.transaction.totalAmount)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Discount:"),
                  pw.Text(formatToIDR(0)), // Assuming no discount for now
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Total:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    formatToIDR(widget.transaction.totalAmount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Cash Received:"),
                  pw.Text(formatToIDR(widget.cashReceived)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Change:"),
                  pw.Text(formatToIDR(widget.changeGiven)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text(_receiptFooter)),
            ],
          );
        },
      ),
    );

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
      if (directory == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access downloads directory.'),
          ),
        );
        return;
      }
      final file = File(
        '${directory.path}/receipt_${widget.transaction.id}.pdf',
      );
      await file.writeAsBytes(await pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved to ${directory.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        leading: IconButton(
          icon: const Icon(Icons.done),
          onPressed: () {
            if (!mounted) return;
            Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ); // Go back to main sales screen
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        _businessName,
                        style: Theme.of(context).textTheme.headlineSmall!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    Text("Transaction ID: ${widget.transaction.id}"),
                    Text("Date: ${widget.transaction.transactionDate}"),
                    const Divider(),
                    Text(
                      "Items:",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...widget.transactionItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "${item.productName} x ${item.quantity}",
                              ),
                            ),
                            Text(formatToIDR(_getItemTotal(item))),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Subtotal:"),
                        Text(formatToIDR(widget.transaction.totalAmount)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Discount:"),
                        Text(formatToIDR(0)), // Assuming no discount for now
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total:",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatToIDR(widget.transaction.totalAmount),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cash Received:"),
                        Text(formatToIDR(widget.cashReceived)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Change:"),
                        Text(formatToIDR(widget.changeGiven)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text(_receiptFooter)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bluetooth Device Selection
            if (_devices.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Bluetooth Printer:'),
                  DropdownButton<BluetoothDevice>(
                    value: _device,
                    hint: const Text('Choose device'),
                    isExpanded: true,
                    items: _devices.map((device) {
                      return DropdownMenuItem<BluetoothDevice>(
                        value: device,
                        child: Text(device.name ?? device.address ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (device) {
                      setState(() {
                        _device = device;
                      });
                    },
                  ),
                ],
              ),
            if (_devices.isEmpty)
              const Text('No Bluetooth devices found. Please scan again.'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _connected ? _disconnect : _connect,
                  child: Text(_connected ? 'Disconnect' : 'Connect'),
                ),
                ElevatedButton(
                  onPressed: _connected
                      ? _printReceipt
                      : null, // Only enable if connected for Bluetooth
                  child: const Text('Print'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateAndSavePdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

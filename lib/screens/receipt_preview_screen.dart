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
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final Transaction transaction;
  final List<TransactionItem> transactionItems;
  final double cashReceived;
  final double changeGiven;

  const ReceiptPreviewScreen({
    Key? key,
    required this.transaction,
    required this.transactionItems,
    required this.cashReceived,
    required this.changeGiven,
  }) : super(key: key);

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  String _selectedPrinterType = 'Bluetooth'; // Default to Bluetooth

  // BluetoothPrintPlus.isConnected is a ValueNotifier<bool>
  bool get _connected => BluetoothPrintPlus.isConnected;

  @override
  void initState() {
    super.initState();
    _loadPrinterType();
    _initBluetooth(); // Call _initBluetooth to start scanning and attempt auto-connect
    BluetoothPrintPlus.connectState.listen((state) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPrinterType = prefs.getString('printerType') ?? 'Bluetooth';
    });
  }

  Future<void> _savePrinterType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerType', type);
  }

  Future<void> _saveLastConnectedDeviceAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastConnectedPrinterAddress', address);
  }

  void _onConnectionChanged() {
    setState(() {});
  }

  Future<void> _initBluetooth() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAddress = prefs.getString('lastConnectedPrinterAddress');

    BluetoothPrintPlus.scanResults.listen((devices) async {
      setState(() {
        _devices = devices;
      });
      if (lastAddress != null && _device == null) { // Only try to auto-connect if no device is currently selected
        final deviceToConnect = devices.firstWhereOrNull((d) => d.address == lastAddress);
        if (deviceToConnect != null) {
          _device = deviceToConnect; // Set the device for UI
          await _connect(); // Attempt to connect
        }
      }
    });

    BluetoothPrintPlus.connectState.listen((state) {
      setState(() {});
    });

    await BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> _connect() async {
    if (_device == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No device selected')));
      return;
    }
    try {
      await BluetoothPrintPlus.connect(_device!);
      await _saveLastConnectedDeviceAddress(_device!.address!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${_device!.name ?? "Printer"}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
    }
  }

  Future<void> _disconnect() async {
    try {
      await BluetoothPrintPlus.disconnect();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disconnected')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to disconnect: $e')));
    }
  }

  double _getItemTotal(TransactionItem item) {
    // Fallback to 0 if null
    return (item.priceAtTransaction ?? 0) * (item.quantity ?? 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _printReceipt() async {
    if (_selectedPrinterType == 'Bluetooth') {
      if (!_connected) {
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
        "PoSHIT Store",
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
        "Thank You!",
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(4);
      bytes += generator.cut();

      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
    } else if (_selectedPrinterType == 'System Printer') {
      // Generate PDF for system printer
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
                    "PoSHIT Store",
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
                  children: [pw.Text("Discount:"), pw.Text(formatToIDR(0))],
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
                pw.Center(child: pw.Text("Thank You!")),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
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
                  "PoSHIT Store",
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
              pw.Center(child: pw.Text("Thank You!")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved to ${directory!.path}')),
      );
    } catch (e) {
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
                        "PoSHIT Store",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                    ...widget.transactionItems
                        .map(
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
                        )
                        .toList(),
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
                    const Center(child: Text("Thank You!")),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                  _savePrinterType(type); // Save the selected type
                }
              },
            ),
            const SizedBox(height: 20), // Add some spacing
            // Bluetooth Printer Selection (only visible if Bluetooth is selected)
            if (_selectedPrinterType == 'Bluetooth') ...[
              DropdownButtonFormField<BluetoothDevice>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Bluetooth Printer',
                ),
                value: _device,
                items: _devices
                    .map(
                      (device) => DropdownMenuItem(
                        value: device,
                        child: Text(device.name ?? "Unknown Device"),
                      ),
                    )
                    .toList(),
                onChanged: (device) {
                  setState(() {
                    _device = device;
                  });
                },
              ),
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
            ] else if (_selectedPrinterType == 'System Printer') ...[
              // For System Printer, the print button is always enabled
              ElevatedButton(
                onPressed: _printReceipt,
                child: const Text('Print'),
              ),
            ],
            const SizedBox(height: 20), // Add some spacing
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

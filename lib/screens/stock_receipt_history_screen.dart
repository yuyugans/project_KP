import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/stock_receipt.dart';
import '../utils/currency_formatter.dart';

class StockReceiptHistoryScreen extends StatefulWidget {
  const StockReceiptHistoryScreen({super.key});

  @override
  State<StockReceiptHistoryScreen> createState() =>
      _StockReceiptHistoryScreenState();
}

class _StockReceiptHistoryScreenState extends State<StockReceiptHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<StockReceipt> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    final receipts = await _databaseHelper.getStockReceipts();
    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _isLoading = false;
    });
  }

  Map<String, List<StockReceipt>> get _invoices {
    final grouped = <String, List<StockReceipt>>{};
    for (final receipt in _receipts) {
      final key =
          '${receipt.invoiceNumber}|${receipt.supplier}|${receipt.invoiceDate.toIso8601String()}';
      grouped.putIfAbsent(key, () => []).add(receipt);
    }
    return grouped;
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  PdfPageFormat _thermalFormat(int itemCount) {
    // Thermal printers feed according to the PDF page height, so use a
    // finite height and reserve 25 mm at the bottom for the paper feed.
    final height = (75 + (itemCount * 9) + 25) * PdfPageFormat.mm;
    return PdfPageFormat(
      57 * PdfPageFormat.mm,
      height,
      marginTop: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 4 * PdfPageFormat.mm,
    );
  }

  Future<void> _printInvoice(List<StockReceipt> invoice) async {
    await Printing.layoutPdf(
      format: _thermalFormat(invoice.length),
      onLayout: (_) => _buildInvoicePdf(invoice),
    );
  }

  Future<Uint8List> _buildInvoicePdf(List<StockReceipt> invoice) async {
    final first = invoice.first;
    final document = pw.Document();
    final total = invoice.fold<double>(
      0,
      (sum, receipt) => sum + receipt.total,
    );

    document.addPage(
      pw.Page(
        pageFormat: _thermalFormat(invoice.length),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'FAKTUR BARANG MASUK',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'No. Faktur: ${first.invoiceNumber}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Pemasok: ${first.supplier}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Tanggal: ${_dateLabel(first.invoiceDate)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Divider(height: 10),
            for (var index = 0; index < invoice.length; index++) ...[
              pw.Text(
                '${index + 1}. ${invoice[index].productName}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${invoice[index].quantity} x ${formatCurrency(invoice[index].buyPrice)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    formatCurrency(invoice[index].total),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (index < invoice.length - 1) pw.SizedBox(height: 4),
            ],
            pw.Divider(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  formatCurrency(total),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              first.paymentStatus == 'paid'
                  ? 'Status: Sudah dibayar'
                  : 'Status: Belum dibayar',
              style: const pw.TextStyle(fontSize: 8),
            ),
            if (first.dueDate != null)
              pw.Text(
                'Jatuh tempo: ${_dateLabel(first.dueDate!)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            if (first.notes.isNotEmpty)
              pw.Text(
                'Catatan: ${first.notes}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ),
      ),
    );

    return document.save();
  }

  Widget _invoiceCard(List<StockReceipt> invoice) {
    final first = invoice.first;
    final total = invoice.fold<double>(
      0,
      (sum, receipt) => sum + receipt.total,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Faktur ${first.invoiceNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cetak faktur',
                  onPressed: () => _printInvoice(invoice),
                  icon: const Icon(Icons.print_outlined),
                ),
              ],
            ),
            Text('Pemasok: ${first.supplier}'),
            Text('Tanggal: ${_dateLabel(first.invoiceDate)}'),
            const Divider(height: 22),
            for (final receipt in invoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(receipt.productName)),
                    Text(
                      '${receipt.quantity} × ${formatCurrency(receipt.buyPrice)}',
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatCurrency(receipt.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${formatCurrency(total)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              first.paymentStatus == 'paid'
                  ? 'Status: Sudah dibayar'
                  : 'Status: Belum dibayar',
              style: TextStyle(
                color: first.paymentStatus == 'paid'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Faktur'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadReceipts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : invoices.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadReceipts,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Belum ada riwayat faktur')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReceipts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: invoices.length,
                itemBuilder: (_, index) => _invoiceCard(invoices[index]),
              ),
            ),
    );
  }
}

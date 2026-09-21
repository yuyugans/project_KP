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

class _StockReceiptHistoryScreenState
    extends State<StockReceiptHistoryScreen> {
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

  Future<void> _printInvoice(List<StockReceipt> invoice) async {
    await Printing.layoutPdf(
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FAKTUR BARANG MASUK',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Nomor Faktur: ${first.invoiceNumber}'),
            pw.Text('Pemasok: ${first.supplier}'),
            pw.Text('Tanggal: ${_dateLabel(first.invoiceDate)}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: const ['No', 'Produk', 'Jumlah', 'Harga Beli', 'Total'],
              data: [
                for (var index = 0; index < invoice.length; index++)
                  [
                    '${index + 1}',
                    invoice[index].productName,
                    '${invoice[index].quantity}',
                    formatCurrency(invoice[index].buyPrice),
                    formatCurrency(invoice[index].total),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTAL: ${formatCurrency(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              first.paymentStatus == 'paid'
                  ? 'Status: Sudah dibayar'
                  : 'Status: Belum dibayar',
            ),
            if (first.dueDate != null)
              pw.Text('Jatuh tempo: ${_dateLabel(first.dueDate!)}'),
            if (first.notes.isNotEmpty) pw.Text('Catatan: ${first.notes}'),
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

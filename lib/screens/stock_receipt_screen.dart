import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/stock_receipt.dart';
import '../utils/currency_formatter.dart';
import 'stock_receipt_history_screen.dart';

class StockReceiptScreen extends StatefulWidget {
  const StockReceiptScreen({super.key});

  @override
  State<StockReceiptScreen> createState() => _StockReceiptScreenState();
}

class _ReceiptItemDraft {
  bool useExistingProduct = true;
  Product? product;
  int? categoryId;
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final sellPriceController = TextEditingController();
  final minStockController = TextEditingController(text: '0');
  final quantityController = TextEditingController();
  final buyPriceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    barcodeController.dispose();
    sellPriceController.dispose();
    minStockController.dispose();
    quantityController.dispose();
    buyPriceController.dispose();
  }
}

class _StockReceiptScreenState extends State<StockReceiptScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_ReceiptItemDraft> _items = [_ReceiptItemDraft()];

  List<Product> _products = [];
  List<Category> _categories = [];
  List<StockReceipt> _receipts = [];
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String _paymentStatus = 'paid';
  bool _isSaving = false;
  bool _isLoadingData = false;
  bool _reloadDataRequested = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoadingData) {
      _reloadDataRequested = true;
      return;
    }

    _isLoadingData = true;
    try {
      do {
        _reloadDataRequested = false;
        final products = await _databaseHelper.getProducts();
        final categories = await _databaseHelper.getCategories();
        final receipts = await _databaseHelper.getStockReceipts();
        if (!mounted) return;
        setState(() {
          _products = products;
          _categories = categories;
          _receipts = receipts;
        });
      } while (_reloadDataRequested);
    } finally {
      _isLoadingData = false;
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickDate({required bool dueDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ? (_dueDate ?? _invoiceDate) : _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (dueDate) {
        _dueDate = picked;
      } else {
        _invoiceDate = picked;
      }
    });
  }

  void _addItem() => setState(() => _items.add(_ReceiptItemDraft()));

  void _removeItem(int index) {
    if (_items.length == 1) return;
    final item = _items.removeAt(index);
    item.dispose();
    setState(() {});
  }

  Future<void> _saveReceipt() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_paymentStatus == 'unpaid' && _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jatuh tempo wajib diisi untuk faktur belum lunas'),
        ),
      );
      return;
    }

    final newProducts = <int, Product>{};
    final receipts = _items.asMap().entries.map((entry) {
      final itemIndex = entry.key;
      final item = entry.value;
      final product = item.useExistingProduct
          ? item.product!
          : Product(
              categoryId: item.categoryId!,
              name: item.nameController.text.trim(),
              barcode: item.barcodeController.text.trim(),
              buyPrice: parseCurrencyInput(item.buyPriceController.text),
              sellPrice: parseCurrencyInput(item.sellPriceController.text),
              stock: 0,
              minStock: int.tryParse(item.minStockController.text) ?? 0,
            );
      final productId = item.useExistingProduct ? product.id! : -(itemIndex + 1);
      if (!item.useExistingProduct) {
        newProducts[productId] = product;
      }
      final quantity = int.parse(item.quantityController.text);
      final buyPrice = parseCurrencyInput(item.buyPriceController.text);
      return StockReceipt(
        productId: productId,
        productName: product.name,
        invoiceNumber: _invoiceController.text.trim(),
        supplier: _supplierController.text.trim(),
        quantity: quantity,
        buyPrice: buyPrice,
        total: quantity * buyPrice,
        paymentStatus: _paymentStatus,
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        notes: _notesController.text.trim(),
      );
    }).toList();

    setState(() => _isSaving = true);
    try {
      await _databaseHelper.insertStockReceiptsWithNewProducts(
        receipts: receipts,
        newProducts: newProducts,
      );
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faktur dan semua barang masuk berhasil disimpan'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan barang masuk: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    final oldItems = List<_ReceiptItemDraft>.of(_items);
    _formKey.currentState?.reset();
    _invoiceController.clear();
    _supplierController.clear();
    _notesController.clear();
    setState(() {
      _items
        ..clear()
        ..add(_ReceiptItemDraft());
      _invoiceDate = DateTime.now();
      _dueDate = null;
      _paymentStatus = 'paid';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in oldItems) {
        item.dispose();
      }
    });
  }

  String? _required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? '$label harus diisi' : null;

  Widget _itemEditor(int index) {
    final item = _items[index];
    final selectedIds = _items
        .where((other) => other != item && other.product != null)
        .map((other) => other.product!.id)
        .toSet();
    final availableProducts = _products
        .where((product) => !selectedIds.contains(product.id))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            final modeField = DropdownButtonFormField<bool>(
              initialValue: item.useExistingProduct,
              decoration: const InputDecoration(labelText: 'Sumber barang'),
              items: const [
                DropdownMenuItem(
                  value: true,
                  child: Text('Barang sudah ada di inventory'),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text('Barang baru'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  item.useExistingProduct = value;
                  if (value) {
                    item.product = null;
                  }
                });
              },
            );
            final productField = DropdownButtonFormField<int>(
              initialValue: item.product?.id,
              decoration: const InputDecoration(labelText: 'Produk'),
              items: availableProducts
                  .map(
                    (product) => DropdownMenuItem(
                      value: product.id,
                      child: Text('${product.name} (stok: ${product.stock})'),
                    ),
                  )
                  .toList(),
              onChanged: (productId) {
                setState(() {
                  item.product = productId == null
                      ? null
                      : _products.firstWhere(
                          (product) => product.id == productId,
                        );
                  final product = item.product;
                  if (product != null) {
                    item.buyPriceController.text = formatCurrency(
                      product.buyPrice,
                    ).substring(3);
                  }
                });
              },
              validator: (_) => item.useExistingProduct && item.product == null
                  ? 'Produk harus dipilih'
                  : null,
            );
            final newProductFields = Column(
              children: [
                TextFormField(
                  controller: item.nameController,
                  decoration: const InputDecoration(labelText: 'Nama barang baru'),
                  validator: (value) => item.useExistingProduct
                      ? null
                      : _required(value, 'Nama barang'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: item.barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode'),
                  validator: (value) => item.useExistingProduct
                      ? null
                      : _required(value, 'Barcode'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: item.categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .where((category) => category.id != null)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    item.categoryId = value;
                  }),
                  validator: (_) => item.useExistingProduct || item.categoryId != null
                      ? null
                      : 'Kategori harus dipilih',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: item.sellPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Harga jual',
                    prefixText: 'Rp ',
                  ),
                  validator: (value) => item.useExistingProduct ||
                          parseCurrencyInput(value ?? '') > 0
                      ? null
                      : 'Harga jual harus lebih dari 0',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: item.minStockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Minimum stok'),
                ),
              ],
            );
            final quantityField = TextFormField(
              controller: item.quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jumlah tambahan'),
              validator: (value) {
                final quantity = int.tryParse(value ?? '') ?? 0;
                return quantity <= 0 ? 'Jumlah harus lebih dari 0' : null;
              },
            );
            final priceField = TextFormField(
              controller: item.buyPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Harga beli baru',
                prefixText: 'Rp ',
              ),
              validator: (value) => parseCurrencyInput(value ?? '') <= 0
                  ? 'Harga beli harus lebih dari 0'
                  : null,
            );

            final removeButton = IconButton(
              onPressed: _items.length == 1 ? null : () => _removeItem(index),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus produk dari faktur',
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                modeField,
                const SizedBox(height: 10),
                if (item.useExistingProduct) productField else newProductFields,
                const SizedBox(height: 10),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 10),
                      Expanded(child: priceField),
                      removeButton,
                    ],
                  )
                else ...[
                  quantityField,
                  const SizedBox(height: 10),
                  priceField,
                  Align(alignment: Alignment.centerRight, child: removeButton),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceTotal = _items.fold<double>(0, (total, item) {
      final quantity = int.tryParse(item.quantityController.text) ?? 0;
      return total +
          quantity * parseCurrencyInput(item.buyPriceController.text);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang Masuk'),
        actions: [
          IconButton(
            tooltip: 'Riwayat faktur',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockReceiptHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catat Pembelian Stok',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 600;
                          final fields = [
                            TextFormField(
                              controller: _invoiceController,
                              decoration: const InputDecoration(
                                labelText: 'Nomor Faktur',
                              ),
                              validator: (value) =>
                                  _required(value, 'Nomor faktur'),
                            ),
                            TextFormField(
                              controller: _supplierController,
                              decoration: const InputDecoration(
                                labelText: 'Pemasok / Pemilik',
                              ),
                              validator: (value) => _required(value, 'Pemasok'),
                            ),
                          ];
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: fields
                                .map(
                                  (field) => SizedBox(
                                    width: wide
                                        ? (constraints.maxWidth - 12) / 2
                                        : constraints.maxWidth,
                                    child: field,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Produk dalam faktur',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_items.length, _itemEditor),
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Produk ke Faktur'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickDate(dueDate: false),
                            icon: const Icon(Icons.event),
                            label: Text('Tanggal: ${_dateLabel(_invoiceDate)}'),
                          ),
                          DropdownButton<String>(
                            value: _paymentStatus,
                            items: const [
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Sudah dibayar'),
                              ),
                              DropdownMenuItem(
                                value: 'unpaid',
                                child: Text('Belum dibayar'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _paymentStatus = value ?? 'paid';
                              if (_paymentStatus == 'paid') _dueDate = null;
                            }),
                          ),
                          if (_paymentStatus == 'unpaid')
                            OutlinedButton.icon(
                              onPressed: () => _pickDate(dueDate: true),
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                _dueDate == null
                                    ? 'Pilih jatuh tempo'
                                    : 'Jatuh tempo: ${_dateLabel(_dueDate!)}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total faktur: ${formatCurrency(invoiceTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveReceipt,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Simpan Faktur'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Barang Masuk',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: Text('Belum ada barang masuk')),
              )
            else
              SizedBox(
                height: 420,
                child: ListView.builder(
                  primary: false,
                  itemCount: _receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = _receipts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: receipt.paymentStatus == 'paid'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          child: Icon(
                            receipt.paymentStatus == 'paid'
                                ? Icons.check
                                : Icons.schedule,
                            color: receipt.paymentStatus == 'paid'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        title: Text(
                          receipt.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Faktur ${receipt.invoiceNumber} • ${receipt.supplier}\n'
                          '${receipt.quantity} pcs × ${formatCurrency(receipt.buyPrice)} = '
                          '${formatCurrency(receipt.total)}\n'
                          '${_dateLabel(receipt.invoiceDate)} • '
                          '${receipt.paymentStatus == 'paid' ? 'Sudah dibayar' : 'Belum dibayar'}'
                          '${receipt.dueDate == null ? '' : ' • Jatuh tempo ${_dateLabel(receipt.dueDate!)}'}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../utils/currency_formatter.dart';
import '../widgets/main_menu_button.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  List<Product> _products = [];
  final List<CartItem> _cart = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final Map<String, TextEditingController> _quantityControllers = {};

  String _searchQuery = '';

  List<Category> _categories = [];

  int? _selectedFilterCategoryId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _barcodeFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _cartItemKey(CartItem item) {
    return '${item.product.id ?? item.product.barcode}';
  }

  TextEditingController _quantityControllerFor(CartItem item) {
    final key = _cartItemKey(item);
    return _quantityControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '${item.quantity}'),
    );
  }

  void _updateQuantityFromInput(CartItem item, String value) {
    final quantity = int.tryParse(value);
    if (quantity == null || quantity < 1) {
      return;
    }

    if (quantity == item.quantity) {
      return;
    }

    if (quantity > item.product.stock) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlah melebihi stok')));
      final controller = _quantityControllerFor(item);
      controller.text = '${item.quantity}';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      return;
    }

    setState(() {
      item.quantity = quantity;
    });
  }

  Future<void> _loadProducts() async {
    final products = await _databaseHelper.getProducts();
    final categories = await _databaseHelper.getCategories();

    setState(() {
      _products = products;
      _categories = categories;
    });
  }

  Future<void> _scanBarcode(String value) async {
    final barcode = value.trim();
    _barcodeController.clear();
    if (barcode.isEmpty) {
      _barcodeFocusNode.requestFocus();
      return;
    }

    final product = await _databaseHelper.getProductByBarcode(barcode);
    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode $barcode tidak terdaftar di database')),
      );
    } else {
      _addToCart(product);
    }

    _barcodeFocusNode.requestFocus();
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final query = _searchQuery.toLowerCase();

      final matchesSearch =
          product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);

      final matchesCategory =
          _selectedFilterCategoryId == null ||
          product.categoryId == _selectedFilterCategoryId;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _getCategoryName(int categoryId) {
    final category = _categories.firstWhere(
      (category) => category.id == categoryId,
      orElse: () => Category(id: categoryId, name: 'Tidak diketahui'),
    );

    return category.name;
  }

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stok produk habis')));
      return;
    }

    final index = _cart.indexWhere((item) => item.product.id == product.id);

    setState(() {
      if (index >= 0) {
        if (_cart[index].quantity < product.stock) {
          _cart[index].quantity++;
          _quantityControllerFor(_cart[index]).text =
              '${_cart[index].quantity}';
        }
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  void _increaseQuantity(int index) {
    final item = _cart[index];

    if (item.quantity >= item.product.stock) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlah melebihi stok')));
      return;
    }

    setState(() {
      item.quantity++;
      _quantityControllerFor(item).text = '${item.quantity}';
    });
  }

  void _decreaseQuantity(int index) {
    final item = _cart[index];
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
        _quantityControllerFor(item).text = '${item.quantity}';
      } else {
        _cart.removeAt(index);
        final controller = _quantityControllers.remove(_cartItemKey(item));
        controller?.dispose();
      }
    });
  }

  double get _total {
    return _cart.fold(0, (sum, item) => sum + item.subtotal);
  }

  Map<int, String> get _categoryNames {
    return {
      for (final category in _categories)
        if (category.id != null) category.id!: category.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MainMenuButton(),
        title: const Text('Kasir'),
      ),
      body: Row(
        children: [
          // =========================
          // DAFTAR PRODUK
          // =========================
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daftar Produk',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk atau barcode...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<int?>(
                    initialValue: _selectedFilterCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Filter Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Semua Kategori'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFilterCategoryId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Scan barcode',
                      hintText: 'Arahkan scanner ke barcode lalu tekan Enter',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _scanBarcode,
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? const Center(child: Text('Belum ada produk'))
                        : ListView.builder(
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(
                                    'Kategori: ${_getCategoryName(product.categoryId)}'
                                    '\n${formatCurrency(product.sellPrice)}'
                                    '\nStok: ${product.stock}',
                                  ),
                                  isThreeLine: true,
                                  trailing: ElevatedButton(
                                    onPressed: product.stock > 0
                                        ? () {
                                            _addToCart(product);
                                          }
                                        : null,
                                    child: const Text('Tambah'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // =========================
          // KERANJANG
          // =========================
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keranjang',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Keranjang masih kosong'))
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        formatCurrency(item.product.sellPrice),
                                      ),

                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              _decreaseQuantity(index);
                                            },
                                            icon: const Icon(Icons.remove),
                                          ),

                                          const SizedBox(width: 4),

                                          SizedBox(
                                            width: 56,
                                            child: TextField(
                                              controller:
                                                  _quantityControllerFor(item),
                                              textAlign: TextAlign.center,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 4,
                                                    ),
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) {
                                                _updateQuantityFromInput(
                                                  item,
                                                  value,
                                                );
                                              },
                                              onSubmitted: (value) {
                                                _updateQuantityFromInput(
                                                  item,
                                                  value,
                                                );
                                              },
                                            ),
                                          ),

                                          const SizedBox(width: 4),

                                          IconButton(
                                            onPressed: () {
                                              _increaseQuantity(index);
                                            },
                                            icon: const Icon(Icons.add),
                                          ),

                                          const Spacer(),

                                          Text(
                                            formatCurrency(item.subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatCurrency(_total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (_cart.isNotEmpty &&
                            event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          _showPaymentDialog();
                          return KeyEventResult.handled;
                        }

                        return KeyEventResult.ignored;
                      },
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty
                            ? null
                            : () {
                                _showPaymentDialog();
                              },
                        child: const Text('PROSES PEMBAYARAN'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    final paymentController = TextEditingController();
    final total = _total;
    var isProcessing = false;

    showDialog(
      context: context,
      builder: (context) {
        Future<void> processPayment() async {
          if (isProcessing) {
            return;
          }

          final payment = parseCurrencyInput(paymentController.text);

          if (payment < total) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Uang pembayaran kurang')),
            );
            return;
          }

          isProcessing = true;
          Navigator.pop(context);
          await _showPaymentSuccess(payment);
        }

        return AlertDialog(
          title: const Text('Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total: ${formatCurrency(total)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: paymentController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                onSubmitted: (_) => processPayment(),
                decoration: const InputDecoration(
                  labelText: 'Uang Pembayaran',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final formattedTotal = total.toStringAsFixed(0);
                    paymentController
                      ..text = formatCurrency(total).substring(3)
                      ..selection = TextSelection.collapsed(
                        offset:
                            formattedTotal.length +
                            (formattedTotal.length - 1) ~/ 3,
                      );
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Uang Pas'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Batal'),
            ),

            ElevatedButton(
              onPressed: processPayment,
              child: const Text('Bayar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPaymentSuccess(double payment) async {
    final receiptItems = List<CartItem>.from(_cart);
    final total = _total;
    final change = payment - total;
    late final int transactionId;

    try {
      transactionId = await _databaseHelper.insertTransaction(
        items: receiptItems,
        categoryNames: _categoryNames,
        total: total,
        payment: payment,
        change: change,
      );
    } on StateError catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) return;

    await _loadProducts();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        void finishPayment() {
          Navigator.pop(context);

          setState(() {
            _cart.clear();
          });
        }

        Future<void> printReceiptAndFinish() async {
          Navigator.pop(context);
          await _printReceipt(
            transactionId: transactionId,
            items: receiptItems,
            total: total,
            payment: payment,
            change: change,
          );
          if (!mounted) return;
          setState(() {
            _cart.clear();
          });
        }

        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Pembayaran Berhasil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 60),

                const SizedBox(height: 16),

                Text('Total: ${formatCurrency(total)}'),

                Text(
                  'Kembalian: ${formatCurrency(change)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Cetak nota pembelian?'),
              ],
            ),
            actions: [
              Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    finishPayment();
                    return KeyEventResult.handled;
                  }

                  return KeyEventResult.ignored;
                },
                child: TextButton(
                  onPressed: finishPayment,
                  child: const Text('Tidak'),
                ),
              ),
              ElevatedButton.icon(
                onPressed: printReceiptAndFinish,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Cetak Nota'),
              ),
            ],
          ),
        );
      },
    );
  }

  PdfPageFormat _receiptFormat(int itemCount) {
    final height = (90 + (itemCount * 10) + 25) * PdfPageFormat.mm;
    return PdfPageFormat(
      57 * PdfPageFormat.mm,
      height,
      marginTop: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 4 * PdfPageFormat.mm,
    );
  }

  Future<void> _printReceipt({
    required int transactionId,
    required List<CartItem> items,
    required double total,
    required double payment,
    required double change,
  }) async {
    try {
      await Printing.layoutPdf(
        format: _receiptFormat(items.length),
        onLayout: (_) => _buildReceiptPdf(
          transactionId: transactionId,
          items: items,
          total: total,
          payment: payment,
          change: change,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mencetak nota: $error')));
    }
  }

  Future<Uint8List> _buildReceiptPdf({
    required int transactionId,
    required List<CartItem> items,
    required double total,
    required double payment,
    required double change,
  }) async {
    final document = pw.Document();
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    document.addPage(
      pw.Page(
        pageFormat: _receiptFormat(items.length),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'NOTA PEMBELIAN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'No. Transaksi: $transactionId',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Tanggal: $dateLabel',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Divider(height: 10),
            for (final item in items) ...[
              pw.Text(
                item.product.name,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${item.quantity} x ${formatCurrency(item.product.sellPrice)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    formatCurrency(item.subtotal),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Divider(height: 10),
            _receiptTotalRow('TOTAL', total),
            _receiptTotalRow('TUNAI', payment),
            _receiptTotalRow('KEMBALIAN', change),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Terima kasih',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  pw.Widget _receiptTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(formatCurrency(amount), style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}

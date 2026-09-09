import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../utils/currency_formatter.dart';

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
  final Map<String, TextEditingController> _quantityControllers = {};

  String _searchQuery = '';

  List<Category> _categories = [];

  int? _selectedFilterCategoryId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      appBar: AppBar(title: const Text('Kasir')),
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
                inputFormatters: const [
                  ThousandsSeparatorInputFormatter(),
                ],
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
                        offset: formattedTotal.length +
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
    final total = _total;
    final change = payment - total;

    try {
      await _databaseHelper.insertTransaction(
        items: List<CartItem>.from(_cart),
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
      builder: (context) {
        void finishPayment() {
          Navigator.pop(context);

          setState(() {
            _cart.clear();
          });
        }

        return AlertDialog(
          title: const Text('Pembayaran Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 60),

              const SizedBox(height: 16),

              Text('Total: ${formatCurrency(_total)}'),

              Text(
                'Kembalian: ${formatCurrency(change)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
              child: ElevatedButton(
                onPressed: finishPayment,
                child: const Text('Selesai'),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  String _searchQuery = '';
  int? _selectedFilterCategoryId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();

    return _products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);

      final matchesCategory =
          _selectedFilterCategoryId == null ||
          product.categoryId == _selectedFilterCategoryId;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _loadProducts() async {
    final products = await _databaseHelper.getProducts();
    final categories = await _databaseHelper.getCategories();

    if (!mounted) return;

    setState(() {
      _products = products;
      _categories = categories;
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final id = product.id;
    if (id == null) return;

    await _databaseHelper.deleteProduct(id);

    if (!mounted) return;

    await _loadProducts();
  }

  Future<void> _showAddProductDialog() async {
    await _showProductDialog();
  }

  Future<void> _showEditProductDialog(Product product) async {
    await _showProductDialog(product: product);
  }

  Future<void> _showProductDialog({Product? product}) async {
    final isEditing = product != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(
      text: product?.barcode ?? '',
    );
    final buyPriceController = TextEditingController(
      text: product == null
          ? ''
          : formatCurrency(product.buyPrice).substring(3),
    );
    final sellPriceController = TextEditingController(
      text: product == null
          ? ''
          : formatCurrency(product.sellPrice).substring(3),
    );
    final stockController = TextEditingController(
      text: product?.stock.toString() ?? '',
    );
    final minStockController = TextEditingController(
      text: product?.minStock.toString() ?? '',
    );

    int? selectedCategoryId = product?.categoryId;
    final dialogContext = context;
    var isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        Future<void> saveProduct() async {
          if (isSaving || !formKey.currentState!.validate()) {
            return;
          }

          final name = nameController.text.trim();
          final barcode = barcodeController.text.trim();
          final buyPrice = parseCurrencyInput(buyPriceController.text);
          final sellPrice = parseCurrencyInput(sellPriceController.text);
          final stock = int.tryParse(stockController.text) ?? 0;
          final minStock = int.tryParse(minStockController.text) ?? 0;

          if (selectedCategoryId == null) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Kategori harus dipilih')),
            );
            return;
          }

          isSaving = true;

          final productToSave = Product(
            id: product?.id,
            categoryId: selectedCategoryId!,
            name: name,
            barcode: barcode,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            stock: stock,
            minStock: minStock,
          );

          if (isEditing) {
            await _databaseHelper.updateProduct(productToSave);
          } else {
            await _databaseHelper.insertProduct(productToSave);
          }

          if (!mounted) return;

          if (context.mounted) {
            Navigator.pop(context);
          }

          await _loadProducts();

          if (!mounted) return;

          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? 'Produk berhasil diperbarui'
                    : 'Produk berhasil ditambahkan',
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk'),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextFormField(
                      controller: nameController,
                      labelText: 'Nama Produk',
                      onFieldSubmitted: (_) => saveProduct(),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Nama produk harus diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      controller: barcodeController,
                      labelText: 'Barcode',
                      onFieldSubmitted: (_) => saveProduct(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Pilih Kategori'),
                        ),
                        ..._categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }),
                      ],
                      validator: (value) {
                        if (value == null) {
                          return 'Kategori harus dipilih';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        selectedCategoryId = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      controller: buyPriceController,
                      labelText: 'Harga Beli',
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      onFieldSubmitted: (_) => saveProduct(),
                      validator: (value) {
                        final parsedValue = parseCurrencyInput(value ?? '');
                        if (parsedValue < 0) {
                          return 'Harga beli tidak boleh negatif';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      controller: sellPriceController,
                      labelText: 'Harga Jual',
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      onFieldSubmitted: (_) => saveProduct(),
                      validator: (value) {
                        final parsedValue = parseCurrencyInput(value ?? '');
                        if (parsedValue <= 0) {
                          return 'Harga jual harus lebih dari 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      controller: stockController,
                      labelText: 'Stok',
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (_) => saveProduct(),
                      validator: (value) {
                        final parsedValue = int.tryParse(value ?? '') ?? 0;
                        if (parsedValue < 0) {
                          return 'Stok tidak boleh negatif';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      controller: minStockController,
                      labelText: 'Minimum Stok',
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (_) => saveProduct(),
                      validator: (value) {
                        final parsedValue = int.tryParse(value ?? '') ?? 0;
                        if (parsedValue < 0) {
                          return 'Minimum stok tidak boleh negatif';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(onPressed: saveProduct, child: const Text('Simpan')),
          ],
        );
      },
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        prefixText: prefixText,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar Produk',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Produk'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau barcode',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedFilterCategoryId,
              decoration: const InputDecoration(
                labelText: 'Filter Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Semua Kategori'),
                ),
                ..._categories.map((category) {
                  return DropdownMenuItem<int>(
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
            const SizedBox(height: 20),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada produk',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${product.stock}'),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Barcode: ${product.barcode}\n'
                              'Harga Beli: ${formatCurrency(product.buyPrice)}\n'
                              'Harga Jual: ${formatCurrency(product.sellPrice)}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Stok',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '${product.stock}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: product.stock <= product.minStock
                                            ? Colors.red
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: 'Edit Produk',
                                  onPressed: () =>
                                      _showEditProductDialog(product),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Hapus Produk',
                                  onPressed: () => _deleteProduct(product),
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
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

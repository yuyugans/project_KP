import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/product_excel_file_saver.dart';
import '../utils/product_excel_export.dart';
import '../utils/product_excel_import.dart';
import '../widgets/main_menu_button.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  String _searchQuery = '';
  Object? _loadError;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isImporting = false;

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
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
    }).toList();
  }

  Map<int, String> get _categoryNames => {
    for (final category in _categories)
      if (category.id != null) category.id!: category.name,
  };

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final products = await _databaseHelper.getProducts();
      final categories = await _databaseHelper.getCategories();
      if (!mounted) return;

      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportExcel(List<Product> products) async {
    if (products.isEmpty || _isExporting) return;
    setState(() => _isExporting = true);

    try {
      final bytes = buildProductExcelBytes(products, _categoryNames);
      final savedLocation = await saveProductExcelFile(
        Uint8List.fromList(bytes),
      );
      if (savedLocation != null) {
        _showMessage('File Excel disimpan di: $savedLocation');
      }
    } catch (error) {
      _showMessage('Gagal mengekspor Excel: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importExcel() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel workbook', extensions: ['xlsx']),
        ],
      );
      if (file == null) return;

      final existingProducts = await _databaseHelper.getProducts();
      final categories = await _databaseHelper.getCategories();
      final result = parseProductExcelBytes(
        await file.readAsBytes(),
        categoryIds: {
          for (final category in categories)
            if (category.id != null) category.name: category.id!,
        },
        existingBarcodes: existingProducts
            .map((product) => product.barcode)
            .toSet(),
      );
      final importedCount = await _databaseHelper.insertProducts(
        result.products,
      );
      await _loadProducts();

      _showMessage(
        'Impor selesai: $importedCount barang ditambahkan, '
        '${result.duplicateBarcodes} duplikat dilewati, '
        '${result.unknownCategories} kategori tidak dikenal dilewati, '
        '${result.invalidRows} baris tidak valid dilewati.',
      );
    } catch (error) {
      _showMessage('Gagal mengimpor Excel: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        leading: const MainMenuButton(),
        title: const Text('Daftar Barang'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama barang atau barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${products.length} barang ditampilkan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading || _isImporting || _isExporting
                      ? null
                      : _importExcel,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Impor'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed:
                      _isLoading ||
                          _isImporting ||
                          _isExporting ||
                          products.isEmpty
                      ? null
                      : () => _exportExcel(products),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Ekspor'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildProductList(products)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat daftar barang: $_loadError'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (products.isEmpty) {
      return const Center(child: Text('Tidak ada barang yang cocok.'));
    }

    final categoryNames = _categoryNames;
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        final isLowStock = product.stock <= product.minStock;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Barcode: ${product.barcode}\n'
              'Kategori: ${categoryNames[product.categoryId] ?? 'Tidak diketahui'}\n'
              'Harga beli: ${formatCurrency(product.buyPrice)} • '
              'Harga jual: ${formatCurrency(product.sellPrice)}\n'
              'Minimum stok: ${product.minStock}',
            ),
            isThreeLine: true,
            trailing: Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text('${product.stock}'),
              backgroundColor: isLowStock ? Colors.red.shade50 : null,
              labelStyle: TextStyle(
                color: isLowStock ? Colors.red : null,
                fontWeight: FontWeight.bold,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}

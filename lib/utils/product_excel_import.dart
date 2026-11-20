import 'package:excel/excel.dart';

import '../models/product.dart';

class ProductExcelImportResult {
  const ProductExcelImportResult({
    required this.products,
    required this.duplicateBarcodes,
    required this.unknownCategories,
    required this.invalidRows,
  });

  final List<Product> products;
  final int duplicateBarcodes;
  final int unknownCategories;
  final int invalidRows;
}

ProductExcelImportResult parseProductExcelBytes(
  List<int> bytes, {
  required Map<String, int> categoryIds,
  required Set<String> existingBarcodes,
}) {
  final workbook = Excel.decodeBytes(bytes);
  final sheetName = workbook.tables.containsKey('Daftar Barang')
      ? 'Daftar Barang'
      : workbook.getDefaultSheet();
  final sheet = sheetName == null ? null : workbook.tables[sheetName];
  if (sheet == null || sheet.rows.isEmpty) {
    throw const FormatException('Sheet Excel tidak berisi data.');
  }

  final headerIndexes = <String, int>{};
  for (var index = 0; index < sheet.rows.first.length; index++) {
    final header = _cellText(sheet.rows.first[index]).toLowerCase();
    if (header.isNotEmpty) headerIndexes[header] = index;
  }

  const requiredHeaders = [
    'nama barang',
    'barcode',
    'kategori',
    'harga beli',
    'harga jual',
    'stok',
    'minimum stok',
  ];
  final missingHeaders = requiredHeaders
      .where((header) => !headerIndexes.containsKey(header))
      .toList();
  if (missingHeaders.isNotEmpty) {
    throw FormatException(
      'Kolom Excel tidak lengkap: ${missingHeaders.join(', ')}.',
    );
  }

  final normalizedCategoryIds = {
    for (final entry in categoryIds.entries)
      entry.key.trim().toLowerCase(): entry.value,
  };
  final seenBarcodes = existingBarcodes
      .map((barcode) => barcode.trim())
      .where((barcode) => barcode.isNotEmpty)
      .toSet();
  final products = <Product>[];
  var duplicateBarcodes = 0;
  var unknownCategories = 0;
  var invalidRows = 0;

  for (final row in sheet.rows.skip(1)) {
    if (row.every((cell) => _cellText(cell).isEmpty)) continue;

    final name = _cellText(_cellAt(row, headerIndexes, 'nama barang'));
    final barcode = _cellText(_cellAt(row, headerIndexes, 'barcode'));
    final categoryName = _cellText(_cellAt(row, headerIndexes, 'kategori'));
    final categoryId = normalizedCategoryIds[categoryName.toLowerCase()];
    final buyPrice = _cellNumber(_cellAt(row, headerIndexes, 'harga beli'));
    final sellPrice = _cellNumber(_cellAt(row, headerIndexes, 'harga jual'));
    final stock = _cellInteger(_cellAt(row, headerIndexes, 'stok'));
    final minStock = _cellInteger(_cellAt(row, headerIndexes, 'minimum stok'));

    if (name.isEmpty ||
        barcode.isEmpty ||
        buyPrice == null ||
        sellPrice == null ||
        buyPrice < 0 ||
        sellPrice < 0 ||
        stock == null ||
        minStock == null ||
        stock < 0 ||
        minStock < 0) {
      invalidRows++;
      continue;
    }

    if (categoryId == null) {
      unknownCategories++;
      continue;
    }

    if (!seenBarcodes.add(barcode)) {
      duplicateBarcodes++;
      continue;
    }

    products.add(
      Product(
        categoryId: categoryId,
        name: name,
        barcode: barcode,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        stock: stock,
        minStock: minStock,
      ),
    );
  }

  return ProductExcelImportResult(
    products: products,
    duplicateBarcodes: duplicateBarcodes,
    unknownCategories: unknownCategories,
    invalidRows: invalidRows,
  );
}

Data? _cellAt(List<Data?> row, Map<String, int> headerIndexes, String header) {
  final index = headerIndexes[header]!;
  return index < row.length ? row[index] : null;
}

String _cellText(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    TextCellValue(:final value) => value.toString().trim(),
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => value.toString(),
    _ => value?.toString().trim() ?? '',
  };
}

double? _cellNumber(Data? cell) {
  final number = double.tryParse(_cellText(cell));
  return number != null && number.isFinite ? number : null;
}

int? _cellInteger(Data? cell) {
  final number = _cellNumber(cell);
  if (number == null || number != number.truncateToDouble()) return null;
  return number.toInt();
}

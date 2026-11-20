import 'package:excel/excel.dart';

import '../models/product.dart';

List<int> buildProductExcelBytes(
  List<Product> products,
  Map<int, String> categoryNames,
) {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Daftar Barang');
  if (!workbook.setDefaultSheet('Daftar Barang')) {
    throw StateError('Sheet daftar barang tidak berhasil disiapkan.');
  }

  final sheet = workbook['Daftar Barang'];
  sheet.appendRow([
    TextCellValue('No.'),
    TextCellValue('Nama Barang'),
    TextCellValue('Barcode'),
    TextCellValue('Kategori'),
    TextCellValue('Harga Beli'),
    TextCellValue('Harga Jual'),
    TextCellValue('Stok'),
    TextCellValue('Minimum Stok'),
  ]);

  for (var index = 0; index < products.length; index++) {
    final product = products[index];
    sheet.appendRow([
      IntCellValue(index + 1),
      TextCellValue(product.name),
      TextCellValue(product.barcode),
      TextCellValue(categoryNames[product.categoryId] ?? 'Tidak diketahui'),
      DoubleCellValue(product.buyPrice),
      DoubleCellValue(product.sellPrice),
      IntCellValue(product.stock),
      IntCellValue(product.minStock),
    ]);
  }

  return workbook.save() ??
      (throw StateError('File Excel tidak berhasil dibuat.'));
}

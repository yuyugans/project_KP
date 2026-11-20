import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kp/utils/product_excel_import.dart';

void main() {
  test('imports valid rows and skips duplicate and unknown-category rows', () {
    final workbook = Excel.createExcel();
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
    sheet.appendRow([
      IntCellValue(1),
      TextCellValue('Kopi'),
      TextCellValue('12345'),
      TextCellValue('Minuman'),
      DoubleCellValue(5000),
      DoubleCellValue(7000),
      IntCellValue(12),
      IntCellValue(3),
    ]);
    sheet.appendRow([
      IntCellValue(2),
      TextCellValue('Teh'),
      TextCellValue('12345'),
      TextCellValue('Minuman'),
      DoubleCellValue(4000),
      DoubleCellValue(6000),
      IntCellValue(5),
      IntCellValue(1),
    ]);
    sheet.appendRow([
      IntCellValue(3),
      TextCellValue('Gula'),
      TextCellValue('67890'),
      TextCellValue('Sembako'),
      DoubleCellValue(8000),
      DoubleCellValue(10000),
      IntCellValue(8),
      IntCellValue(2),
    ]);

    final result = parseProductExcelBytes(
      workbook.save()!,
      categoryIds: {'Minuman': 2},
      existingBarcodes: {'99999'},
    );

    expect(result.products, hasLength(1));
    expect(result.products.single.name, 'Kopi');
    expect(result.products.single.categoryId, 2);
    expect(result.duplicateBarcodes, 1);
    expect(result.unknownCategories, 1);
    expect(result.invalidRows, 0);
  });

  test('rejects a workbook without required columns', () {
    final workbook = Excel.createExcel();
    workbook['Daftar Barang'].appendRow([TextCellValue('Nama')]);

    expect(
      () => parseProductExcelBytes(
        workbook.save()!,
        categoryIds: const {},
        existingBarcodes: const {},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('skips rows with missing cells instead of aborting the import', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['Daftar Barang'];
    sheet.appendRow([
      TextCellValue('Nama Barang'),
      TextCellValue('Barcode'),
      TextCellValue('Kategori'),
      TextCellValue('Harga Beli'),
      TextCellValue('Harga Jual'),
      TextCellValue('Stok'),
      TextCellValue('Minimum Stok'),
    ]);
    sheet.appendRow([
      TextCellValue('Kopi'),
      TextCellValue('12345'),
      TextCellValue('Minuman'),
    ]);

    final result = parseProductExcelBytes(
      workbook.save()!,
      categoryIds: {'Minuman': 2},
      existingBarcodes: const {},
    );

    expect(result.products, isEmpty);
    expect(result.invalidRows, 1);
  });
}

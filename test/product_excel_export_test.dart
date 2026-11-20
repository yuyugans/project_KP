import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kp/models/product.dart';
import 'package:project_kp/utils/product_excel_export.dart';

void main() {
  test('workbook opens on the populated product list sheet', () {
    final bytes = buildProductExcelBytes(
      [
        Product(
          id: 1,
          categoryId: 2,
          name: 'Kopi',
          barcode: '12345',
          buyPrice: 5000,
          sellPrice: 7000,
          stock: 12,
          minStock: 3,
        ),
      ],
      {2: 'Minuman'},
    );

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.getDefaultSheet(), 'Daftar Barang');

    final rows = workbook.tables['Daftar Barang']!.rows;
    expect(rows, hasLength(2));
    expect(rows[0][1]!.value.toString(), 'Nama Barang');
    expect(rows[1][1]!.value.toString(), 'Kopi');
    expect(rows[1][3]!.value.toString(), 'Minuman');
  });
}

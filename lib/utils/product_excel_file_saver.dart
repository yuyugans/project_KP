import 'dart:typed_data';

import 'product_excel_file_saver_stub.dart'
    if (dart.library.io) 'product_excel_file_saver_io.dart'
    if (dart.library.js_interop) 'product_excel_file_saver_web.dart'
    as saver;

Future<String?> saveProductExcelFile(Uint8List bytes) {
  return saver.saveProductExcelFile(bytes);
}

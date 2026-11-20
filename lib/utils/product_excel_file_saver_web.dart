import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<String?> saveProductExcelFile(Uint8List bytes) {
  return FileSaver.instance.saveFile(
    name: 'daftar_barang',
    bytes: bytes,
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

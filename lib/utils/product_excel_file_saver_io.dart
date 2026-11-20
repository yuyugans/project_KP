import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:file_saver/file_saver.dart';

Future<String?> saveProductExcelFile(Uint8List bytes) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final location = await getSaveLocation(
      suggestedName: 'daftar_barang.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel workbook', extensions: ['xlsx']),
      ],
    );
    if (location == null) return null;

    final path = location.path.toLowerCase().endsWith('.xlsx')
        ? location.path
        : '${location.path}.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  return FileSaver.instance.saveFile(
    name: 'daftar_barang',
    bytes: bytes,
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Comparte archivos en memoria, compatible con web, iOS, Android y escritorio.
class FileShareHelper {
  FileShareHelper._();

  static const String excelMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<void> shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? shareText,
    String? subject,
  }) async {
    final file = XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: fileName,
    );

    await Share.shareXFiles(
      [file],
      text: shareText,
      subject: subject,
    );
  }

  static Future<void> shareTextContent({
    required String content,
    required String fileName,
    required String mimeType,
    String? shareText,
    String? subject,
    bool bom = false,
  }) {
    final text = bom ? '\uFEFF$content' : content;
    return shareBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      mimeType: mimeType,
      shareText: shareText,
      subject: subject,
    );
  }
}

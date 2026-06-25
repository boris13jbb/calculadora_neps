import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Archivo listo para compartir en el sheet nativo.
class PreparedShareFile {
  const PreparedShareFile({
    required this.file,
    required this.fileName,
  });

  final XFile file;
  final String fileName;
}

/// Comparte o guarda archivos según la plataforma.
class FileShareHelper {
  FileShareHelper._();

  static const String excelMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static bool get isDesktopNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get isMobileNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<ShareResult> shareFiles({
    required List<XFile> inputFiles,
    List<String>? fileNameOverrides,
    String? text,
    String? subject,
    String? title,
    Rect? sharePositionOrigin,
  }) async {
    if (inputFiles.isEmpty) {
      throw ArgumentError('Se requiere al menos un archivo para compartir.');
    }

    final names = _resolveFileNames(inputFiles, fileNameOverrides);
    final files = <XFile>[];

    for (var i = 0; i < inputFiles.length; i++) {
      files.add(await _ensureFileOnDisk(inputFiles[i], names[i]));
    }

    // En escritorio, el texto del share suele reemplazar los archivos (p. ej. WhatsApp).
    final shareText = isDesktopNative ? null : text;
    final shareTitle = title ?? subject ?? text ?? names.first;

    return SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: names,
        text: shareText,
        subject: subject,
        title: shareTitle,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static Future<void> shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? shareText,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (isDesktopNative) {
      final saved = await promptSaveBytes(
        bytes: bytes,
        fileName: fileName,
        dialogTitle: 'Guardar $fileName',
        allowedExtensions: [_extensionFromName(fileName)],
      );
      if (!saved) {
        throw StateError('Guardado cancelado por el usuario.');
      }
      return;
    }

    await shareFiles(
      inputFiles: [
        XFile.fromData(
          bytes,
          mimeType: mimeType,
          name: fileName,
        ),
      ],
      fileNameOverrides: [fileName],
      text: shareText,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareTextContent({
    required String content,
    required String fileName,
    required String mimeType,
    String? shareText,
    String? subject,
    bool bom = false,
    Rect? sharePositionOrigin,
  }) {
    final text = bom ? '\uFEFF$content' : content;
    return shareBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      mimeType: mimeType,
      shareText: shareText,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<String?> deliverPreparedFiles({
    required List<PreparedShareFile> files,
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError('No hay archivos para entregar.');
    }

    final materialized = await _materializePreparedFiles(files);

    if (isDesktopNative) {
      final exportDir = await getDesktopExportDirectory();
      final savedFiles = <PreparedShareFile>[];

      for (final item in materialized) {
        final path = '${exportDir.path}/${item.fileName}';
        await File(path).writeAsBytes(
          await item.file.readAsBytes(),
          flush: true,
        );
        savedFiles.add(
          PreparedShareFile(
            fileName: item.fileName,
            file: XFile(
              path,
              mimeType: item.file.mimeType,
              name: item.fileName,
            ),
          ),
        );
      }

      await openDirectoryInShell(exportDir);

      if (savedFiles.length == 1) {
        await shareFiles(
          inputFiles: [savedFiles.first.file],
          fileNameOverrides: [savedFiles.first.fileName],
          subject: subject,
          title: subject ?? savedFiles.first.fileName,
          sharePositionOrigin: sharePositionOrigin,
        );
        return 'Archivo guardado en ${exportDir.path}. '
            'Si WhatsApp no adjunta el documento, use el clip y selecciónelo '
            'desde esa carpeta.';
      }

      return '${savedFiles.length} archivos guardados en:\n${exportDir.path}\n'
          'En WhatsApp use el clip y selecciónelos desde esa carpeta.';
    }

    await shareFiles(
      inputFiles: materialized.map((item) => item.file).toList(),
      fileNameOverrides: materialized.map((item) => item.fileName).toList(),
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
    return null;
  }

  static Future<bool> promptSaveBytes({
    required Uint8List bytes,
    required String fileName,
    required String dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    final extensions = allowedExtensions ?? [_extensionFromName(fileName)];
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extensions,
      bytes: bytes,
      lockParentWindow: true,
    );
    return path != null && path.isNotEmpty;
  }

  static Future<Directory> getDesktopExportDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/VICUNHA_Neps/exportaciones');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> openDirectoryInShell(Directory directory) async {
    if (kIsWeb) return;

    final path = directory.path;
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  static List<String> _resolveFileNames(
    List<XFile> files,
    List<String>? overrides,
  ) {
    if (overrides != null) {
      assert(
        overrides.length == files.length,
        'fileNameOverrides debe tener la misma cantidad que files.',
      );
      return overrides;
    }

    return List<String>.generate(files.length, (index) {
      final candidate = files[index].name.trim();
      return candidate.isEmpty ? 'archivo_$index.dat' : candidate;
    });
  }

  static Future<List<PreparedShareFile>> _materializePreparedFiles(
    List<PreparedShareFile> files,
  ) async {
    final materialized = <PreparedShareFile>[];
    for (final item in files) {
      final onDisk = await _ensureFileOnDisk(item.file, item.fileName);
      materialized.add(
        PreparedShareFile(file: onDisk, fileName: item.fileName),
      );
    }
    return materialized;
  }

  static Future<XFile> _ensureFileOnDisk(XFile file, String fileName) async {
    final safeName = _sanitizeFileName(fileName);

    if (!kIsWeb && file.path.isNotEmpty) {
      final existing = File(file.path);
      if (await existing.exists()) {
        return XFile(
          existing.path,
          mimeType: file.mimeType,
          name: safeName,
        );
      }
    }

    if (kIsWeb) {
      return XFile.fromData(
        await file.readAsBytes(),
        mimeType: file.mimeType,
        name: safeName,
      );
    }

    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/vicunha_exports');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final path = '${folder.path}/$safeName';
    await File(path).writeAsBytes(await file.readAsBytes(), flush: true);

    return XFile(
      path,
      mimeType: file.mimeType,
      name: safeName,
    );
  }

  static String _sanitizeFileName(String fileName) {
    final cleaned = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'archivo.dat' : cleaned;
  }

  static String _extensionFromName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return 'dat';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

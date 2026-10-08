import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/pdf_item.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _metadataFilename = 'recent_pdfs.json';

  Future<Directory> getAppPdfDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(appDir.path, 'PaperLinkPDFs'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  Future<File> _getMetadataFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, _metadataFilename));
  }

  Future<List<PdfItem>> getRecentPdfs() async {
    try {
      final file = await _getMetadataFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }
      final items = PdfItem.decodeList(content);

      // Filter out files that no longer exist on disk
      final existingItems = <PdfItem>[];
      for (final item in items) {
        if (await File(item.path).exists()) {
          existingItems.add(item);
        }
      }
      // Sort newest first
      existingItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return existingItems;
    } catch (e) {
      return [];
    }
  }

  Future<void> savePdfItem(PdfItem item) async {
    final items = await getRecentPdfs();
    // Remove if already exists with same ID
    items.removeWhere((i) => i.id == item.id);
    items.insert(0, item);

    final file = await _getMetadataFile();
    await file.writeAsString(PdfItem.encodeList(items));
  }

  Future<void> deletePdfItem(String id) async {
    final items = await getRecentPdfs();
    final targetIndex = items.indexWhere((i) => i.id == id);
    if (targetIndex != -1) {
      final target = items[targetIndex];
      try {
        final pdfFile = File(target.path);
        if (await pdfFile.exists()) {
          await pdfFile.delete();
        }
        if (target.thumbnailPath != null) {
          final thumbFile = File(target.thumbnailPath!);
          if (await thumbFile.exists()) {
            await thumbFile.delete();
          }
        }
      } catch (_) {}
      items.removeAt(targetIndex);
      final file = await _getMetadataFile();
      await file.writeAsString(PdfItem.encodeList(items));
    }
  }

  Future<String> generateFilename(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final prefix = 'PaperLink_$dateStr';

    final items = await getRecentPdfs();
    int highestSeq = 0;

    for (final item in items) {
      if (item.filename.startsWith(prefix)) {
        final remaining = item.filename.substring(prefix.length); // e.g. _001.pdf
        final match = RegExp(r'_(\d+)\.pdf$').firstMatch(remaining);
        if (match != null) {
          final seqStr = match.group(1);
          if (seqStr != null) {
            final seq = int.tryParse(seqStr) ?? 0;
            if (seq > highestSeq) {
              highestSeq = seq;
            }
          }
        }
      }
    }

    final nextSeq = (highestSeq + 1).toString().padLeft(3, '0');
    return '${prefix}_$nextSeq.pdf';
  }
}

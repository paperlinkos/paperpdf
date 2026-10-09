import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_item.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _metadataFilename = 'recent_pdfs.json';
  static const String _prefIntroSeen = 'intro_banner_seen_v1';

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

  /// Sanitizes raw filename string: trims whitespace, strips invalid OS characters,
  /// and ensures a single `.pdf` extension.
  String sanitizeFilename(String rawName) {
    var name = rawName.trim();
    if (name.isEmpty) return '';

    // Strip/replace invalid filename characters across platforms: / \ : * ? " < > | \0
    name = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '_');

    // Handle repeated .pdf suffixes (e.g. "doc.pdf.pdf" -> "doc.pdf")
    while (RegExp(r'\.pdf\.pdf$', caseSensitive: false).hasMatch(name)) {
      name = name.substring(0, name.length - 4);
    }

    // Append .pdf extension if not present (case-insensitive check)
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }

    return name;
  }

  /// Checks whether a PDF file with [filename] exists in physical storage or metadata.
  Future<bool> pdfFileExists(String filename) async {
    final sanitized = sanitizeFilename(filename);
    if (sanitized.isEmpty) return false;

    final targetDir = await getAppPdfDirectory();
    final file = File(p.join(targetDir.path, sanitized));
    if (await file.exists()) return true;

    final items = await getRecentPdfs();
    return items.any((item) => item.filename.toLowerCase() == sanitized.toLowerCase());
  }

  /// Generates a unique non-conflicting filename by appending `(1)`, `(2)`, etc. if needed.
  Future<String> getUniqueFilename(String filename) async {
    var sanitized = sanitizeFilename(filename);
    if (sanitized.isEmpty) {
      sanitized = await generateFilename(DateTime.now());
    }

    if (!await pdfFileExists(sanitized)) {
      return sanitized;
    }

    final baseName = sanitized.substring(0, sanitized.length - 4);
    int counter = 1;

    while (true) {
      final candidate = '$baseName ($counter).pdf';
      if (!await pdfFileExists(candidate)) {
        return candidate;
      }
      counter++;
    }
  }

  Future<PdfItem?> renamePdfItem(String id, String newName, {bool overwrite = false}) async {
    var sanitizedName = sanitizeFilename(newName);
    if (sanitizedName.isEmpty) return null;

    final items = await getRecentPdfs();
    final index = items.indexWhere((i) => i.id == id);
    if (index == -1) return null;

    final oldItem = items[index];
    if (oldItem.filename == sanitizedName) return oldItem;

    final oldFile = File(oldItem.path);
    if (!await oldFile.exists()) return null;

    final targetDir = oldFile.parent;
    var targetPath = p.join(targetDir.path, sanitizedName);

    if (!overwrite && await File(targetPath).exists()) {
      sanitizedName = await getUniqueFilename(sanitizedName);
      targetPath = p.join(targetDir.path, sanitizedName);
    }

    if (targetPath != oldItem.path) {
      final newFile = await oldFile.rename(targetPath);
      final updatedItem = PdfItem(
        id: oldItem.id,
        filename: sanitizedName,
        path: newFile.path,
        createdAt: oldItem.createdAt,
        pageCount: oldItem.pageCount,
        fileSizeBytes: await newFile.length(),
        thumbnailPath: oldItem.thumbnailPath,
      );

      items[index] = updatedItem;
      final file = await _getMetadataFile();
      await file.writeAsString(PdfItem.encodeList(items));
      return updatedItem;
    }

    return oldItem;
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
    final prefix = 'PaperLink_Document_$dateStr';

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

  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefIntroSeen) ?? false;
  }

  Future<void> dismissIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIntroSeen, true);
  }
}

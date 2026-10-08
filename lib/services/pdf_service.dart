import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../models/page_item.dart';
import '../models/pdf_item.dart';
import 'image_service.dart';
import 'storage_service.dart';

enum PdfQualityPreset {
  standard, // Optimized for small file size (~150-250 KB / page)
  highQuality, // Optimized for maximum readability (~450-800 KB / page)
}

class PdfService {
  final StorageService _storageService = StorageService();
  final ImageService _imageService = ImageService();

  static String getPresetLabel(PdfQualityPreset preset) {
    switch (preset) {
      case PdfQualityPreset.standard:
        return 'Standard (Smaller File Size)';
      case PdfQualityPreset.highQuality:
        return 'High Quality (Max Readability)';
    }
  }

  static String estimateFileSize(int pageCount, PdfQualityPreset preset) {
    if (pageCount == 0) return '0 KB';
    double avgBytesPerPage;
    if (preset == PdfQualityPreset.standard) {
      avgBytesPerPage = 200 * 1024; // ~200 KB per page
    } else {
      avgBytesPerPage = 600 * 1024; // ~600 KB per page
    }

    final totalBytes = (pageCount * avgBytesPerPage).round();
    if (totalBytes < 1000 * 1024) {
      return '~ ${(totalBytes / 1024).toStringAsFixed(0)} KB';
    } else {
      return '~ ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<PdfItem> createPdf({
    required List<PageItem> pages,
    PdfQualityPreset qualityPreset = PdfQualityPreset.standard,
    String? customFilename,
  }) async {
    if (pages.isEmpty) {
      throw Exception('Cannot create PDF with 0 pages.');
    }

    final pdf = pw.Document(
      title: 'PaperLink PDF Document',
      author: 'PaperLink PDF',
    );

    final maxDim = qualityPreset == PdfQualityPreset.standard ? 1400 : 2400;
    final jpegQuality = qualityPreset == PdfQualityPreset.standard ? 70 : 90;

    for (int i = 0; i < pages.length; i++) {
      final pageItem = pages[i];
      final processedPath = await _imageService.processImageAdjustments(
        pageItem,
        maxDimension: maxDim,
        quality: jpegQuality,
      );
      final imageFile = File(processedPath);

      if (!await imageFile.exists()) {
        continue; // Skip invalid or missing files gracefully
      }

      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    final targetDir = await _storageService.getAppPdfDirectory();
    final now = DateTime.now();
    final filename = customFilename ?? await _storageService.generateFilename(now);
    final pdfFilePath = p.join(targetDir.path, filename);

    final outputFile = File(pdfFilePath);
    final pdfBytes = await pdf.save();
    await outputFile.writeAsBytes(pdfBytes);

    final fileSizeBytes = await outputFile.length();

    // Use first page image path as thumbnail source if available
    String? thumbnailPath;
    try {
      if (pages.isNotEmpty) {
        thumbnailPath = pages.first.currentPath;
      }
    } catch (_) {}

    final pdfItem = PdfItem(
      id: const Uuid().v4(),
      filename: filename,
      path: pdfFilePath,
      createdAt: now,
      pageCount: pages.length,
      fileSizeBytes: fileSizeBytes,
      thumbnailPath: thumbnailPath,
    );

    await _storageService.savePdfItem(pdfItem);
    return pdfItem;
  }
}

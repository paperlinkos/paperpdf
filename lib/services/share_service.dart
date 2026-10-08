import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> sharePdf(String filePath, {String? filename}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('Share file does not exist: $filePath');
      return;
    }

    try {
      final xFile = XFile(
        filePath,
        mimeType: 'application/pdf',
        name: filename ?? 'PaperLink_Document.pdf',
      );
      await Share.shareXFiles(
        [xFile],
        text: 'Document created with PaperLink PDF',
        subject: filename ?? 'PaperLink PDF Document',
      );
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
    }
  }

  static Future<OpenResult> openPdf(String filePath) async {
    try {
      return await OpenFilex.open(filePath, type: 'application/pdf');
    } catch (e) {
      debugPrint('Error opening PDF: $e');
      return OpenResult(
        type: ResultType.error,
        message: 'Could not open file: $e',
      );
    }
  }
}

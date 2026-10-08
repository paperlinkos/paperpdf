import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<bool> sharePdf(String filePath, {String? filename, BuildContext? context}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to share: PDF file was not found on device.'),
            ),
          );
        }
        return false;
      }

      final xFile = XFile(
        filePath,
        mimeType: 'application/pdf',
        name: filename ?? 'PaperLink_Document.pdf',
      );

      final result = await Share.shareXFiles(
        [xFile],
        text: 'Document created with PaperLink PDF',
        subject: filename ?? 'PaperLink PDF Document',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch share menu. Please try again.'),
          ),
        );
      }
      return false;
    }
  }

  static Future<OpenResult> openPdf(String filePath, {BuildContext? context}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        final err = OpenResult(
          type: ResultType.fileNotFound,
          message: 'PDF file was not found on device.',
        );
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.message)),
          );
        }
        return err;
      }

      final result = await OpenFilex.open(filePath, type: 'application/pdf');

      if (result.type != ResultType.done && context != null && context.mounted) {
        String userMessage = 'Could not open PDF with external app.';
        if (result.type == ResultType.noAppToOpen) {
          userMessage = 'No PDF viewer application found on device.';
        } else if (result.type == ResultType.permissionDenied) {
          userMessage = 'Permission denied to access this file.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error opening PDF: $e');
      final err = OpenResult(
        type: ResultType.error,
        message: 'Could not open PDF file.',
      );
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
      return err;
    }
  }
}

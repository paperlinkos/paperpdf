import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../models/pdf_item.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

class PdfResultScreen extends StatelessWidget {
  final PdfItem pdfItem;
  final bool isNewCreated;

  const PdfResultScreen({
    super.key,
    required this.pdfItem,
    this.isNewCreated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('PDF Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Return to home screen
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.cardLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: AppTheme.primaryGreen, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pdfItem.filename,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pdfItem.pageCount} ${pdfItem.pageCount == 1 ? 'page' : 'pages'} • ${pdfItem.formattedSize}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),

            // PDF Render View
            Expanded(
              child: PdfPreview(
                build: (format) async {
                  final file = File(pdfItem.path);
                  if (await file.exists()) {
                    return await file.readAsBytes();
                  } else {
                    throw Exception('PDF file not found on device');
                  }
                },
                allowPrinting: false,
                allowSharing: false, // We use custom primary share button for explicit WhatsApp UX
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                ),
                onError: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading PDF preview: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.backgroundLight,
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary Button: Share PDF
                  ElevatedButton.icon(
                    onPressed: () {
                      ShareService.sharePdf(
                        pdfItem.path,
                        filename: pdfItem.filename,
                      );
                    },
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share PDF'),
                  ),
                  const SizedBox(height: 12),

                  // Secondary Button: Save / Open in External App
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await ShareService.openPdf(pdfItem.path);
                      if (result.type != ResultType.done && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.message.isNotEmpty
                                  ? result.message
                                  : 'Could not open file with external app.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: const Text('Save / Open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

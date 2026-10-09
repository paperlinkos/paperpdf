import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../models/pdf_item.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PdfResultScreen extends StatefulWidget {
  final PdfItem pdfItem;
  final bool isNewCreated;

  const PdfResultScreen({
    super.key,
    required this.pdfItem,
    this.isNewCreated = false,
  });

  @override
  State<PdfResultScreen> createState() => _PdfResultScreenState();
}

class _PdfResultScreenState extends State<PdfResultScreen> {
  late PdfItem _currentPdf;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _currentPdf = widget.pdfItem;
  }

  Future<void> _renamePdf() async {
    final baseName = _currentPdf.filename.endsWith('.pdf')
        ? _currentPdf.filename.substring(0, _currentPdf.filename.length - 4)
        : _currentPdf.filename;
    final controller = TextEditingController(text: baseName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Filename',
            suffixText: '.pdf',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      final updated = await _storageService.renamePdfItem(_currentPdf.id, newName);
      if (updated != null && mounted) {
        setState(() {
          _currentPdf = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to ${updated.filename}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('PDF Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Rename PDF',
            onPressed: _renamePdf,
          ),
        ],
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
                      const Icon(Icons.picture_as_pdf, color: AppTheme.primaryGreen, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentPdf.filename,
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
                              '${_currentPdf.pageCount} ${_currentPdf.pageCount == 1 ? 'page' : 'pages'} • ${_currentPdf.formattedSize}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                        tooltip: 'Rename',
                        onPressed: _renamePdf,
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
                  final file = File(_currentPdf.path);
                  if (await file.exists()) {
                    return await file.readAsBytes();
                  } else {
                    throw Exception('PDF file not found on device');
                  }
                },
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                ),
                onError: (context, error) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          SizedBox(height: 12),
                          Text(
                            'Could not display PDF preview.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
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
                  // Primary Button: "Share PDF"
                  ElevatedButton.icon(
                    onPressed: () {
                      ShareService.sharePdf(
                        _currentPdf.path,
                        filename: _currentPdf.filename,
                        context: context,
                      );
                    },
                    icon: const Icon(Icons.share, size: 22),
                    label: const Text('Share PDF'),
                  ),
                  const SizedBox(height: 12),

                  // Secondary Buttons Row: Open PDF & Rename
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ShareService.openPdf(_currentPdf.path, context: context);
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _renamePdf,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Rename'),
                        ),
                      ),
                    ],
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

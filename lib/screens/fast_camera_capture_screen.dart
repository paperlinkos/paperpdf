import 'dart:io';
import 'package:flutter/material.dart';
import '../models/page_item.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

class FastCameraCaptureScreen extends StatefulWidget {
  const FastCameraCaptureScreen({super.key});

  @override
  State<FastCameraCaptureScreen> createState() => _FastCameraCaptureScreenState();
}

class _FastCameraCaptureScreenState extends State<FastCameraCaptureScreen> {
  final List<PageItem> _capturedPages = [];
  final ImageService _imageService = ImageService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureNextPage();
    });
  }

  Future<void> _captureNextPage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final page = await _imageService.pickImageFromCamera(autoDetect: true);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (page != null) {
        setState(() {
          _capturedPages.add(page);
        });
      }
    }
  }

  void _finishCapture() {
    Navigator.pop(context, _capturedPages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Multi-Page Capture (${_capturedPages.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, _capturedPages);
          },
        ),
        actions: [
          if (_capturedPages.isNotEmpty)
            TextButton(
              onPressed: _finishCapture,
              child: Text(
                'Done (${_capturedPages.length})',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppTheme.cardLight,
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capturedPages.isEmpty
                              ? 'Capture first document page'
                              : '${_capturedPages.length} ${_capturedPages.length == 1 ? 'page' : 'pages'} captured',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Automatic document boundary detection is active.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),

            // Captured pages preview tray
            Expanded(
              child: _capturedPages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isProcessing)
                              const Column(
                                children: [
                                  CircularProgressIndicator(color: AppTheme.primaryGreen),
                                  SizedBox(height: 16),
                                  Text('Detecting document edges...'),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, size: 64, color: AppTheme.textSecondary),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _captureNextPage,
                                    icon: const Icon(Icons.camera),
                                    label: const Text('Take Photo'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _capturedPages.length,
                      itemBuilder: (context, index) {
                        final page = _capturedPages[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(page.currentPath),
                                width: 44,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text('Page ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              page.wasAutoCropped ? 'Auto-cropped document' : 'Full frame photo',
                              style: TextStyle(
                                color: page.wasAutoCropped ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                              onPressed: () {
                                setState(() {
                                  _capturedPages.removeAt(index);
                                });
                              },
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
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _captureNextPage,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_capturedPages.isEmpty ? 'Snap Photo' : 'Snap Next Page'),
                  ),
                  if (_capturedPages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _finishCapture,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text('Done (${_capturedPages.length} ${_capturedPages.length == 1 ? 'Page' : 'Pages'})'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

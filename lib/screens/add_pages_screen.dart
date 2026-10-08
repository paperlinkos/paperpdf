import 'dart:io';
import 'package:flutter/material.dart';
import '../models/page_item.dart';
import '../services/image_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import 'fast_camera_capture_screen.dart';
import 'image_adjust_screen.dart';
import 'pdf_result_screen.dart';

class AddPagesScreen extends StatefulWidget {
  final List<PageItem> initialPages;

  const AddPagesScreen({
    super.key,
    this.initialPages = const [],
  });

  @override
  State<AddPagesScreen> createState() => _AddPagesScreenState();
}

class _AddPagesScreenState extends State<AddPagesScreen> {
  final List<PageItem> _pages = [];
  final ImageService _imageService = ImageService();
  final PdfService _pdfService = PdfService();
  PdfQualityPreset _selectedQuality = PdfQualityPreset.standard;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _pages.addAll(widget.initialPages);
    if (_pages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddPagesSourceModal();
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _imageService.pickImagesFromGallery(autoDetect: true);
    if (picked.isNotEmpty) {
      setState(() {
        _pages.addAll(picked);
      });
    }
  }

  Future<void> _launchFastCameraCapture() async {
    final captured = await Navigator.push<List<PageItem>>(
      context,
      MaterialPageRoute(
        builder: (context) => const FastCameraCaptureScreen(),
      ),
    );

    if (captured != null && captured.isNotEmpty) {
      setState(() {
        _pages.addAll(captured);
      });
    }
  }

  void _showAddPagesSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Document Pages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.cardLight,
                    child: Icon(Icons.photo_library, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Select from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose one or multiple photos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.cardLight,
                    child: Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Multi-Page Camera Capture', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Snap pages sequentially with auto edge crop'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchFastCameraCapture();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQualitySelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF Quality & Size',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose output quality preset for your PDF:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Standard Quality Radio
                    RadioListTile<PdfQualityPreset>(
                      value: PdfQualityPreset.standard,
                      groupValue: _selectedQuality,
                      activeColor: AppTheme.primaryGreen,
                      title: const Text('Standard', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Smaller file size • Estimated: ${PdfService.estimateFileSize(_pages.length, PdfQualityPreset.standard)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _selectedQuality = val);
                          setState(() => _selectedQuality = val);
                        }
                      },
                    ),

                    // High Quality Radio
                    RadioListTile<PdfQualityPreset>(
                      value: PdfQualityPreset.highQuality,
                      groupValue: _selectedQuality,
                      activeColor: AppTheme.primaryGreen,
                      title: const Text('High Quality', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Maximum readability • Estimated: ${PdfService.estimateFileSize(_pages.length, PdfQualityPreset.highQuality)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _selectedQuality = val);
                          setState(() => _selectedQuality = val);
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _generatePdf();
                      },
                      child: Text('Generate PDF (${PdfService.estimateFileSize(_pages.length, _selectedQuality)})'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAdjustScreen(int index) async {
    final updatedPage = await Navigator.push<PageItem>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageAdjustScreen(page: _pages[index]),
      ),
    );

    if (updatedPage != null) {
      setState(() {
        _pages[index] = updatedPage;
      });
    }
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
  }

  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  Future<void> _generatePdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image page.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final pdfItem = await _pdfService.createPdf(
        pages: _pages,
        qualityPreset: _selectedQuality,
      );

      if (!mounted) return;
      setState(() => _isGenerating = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PdfResultScreen(
            pdfItem: pdfItem,
            isNewCreated: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Document Pages (${_pages.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Add Pages',
            onPressed: _showAddPagesSourceModal,
          ),
        ],
      ),
      body: SafeArea(
        child: _pages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_add_outlined, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'No pages added yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select photos from gallery or snap with multi-page camera to build your PDF.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddPagesSourceModal,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Pages'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Quality Selector Bar
                  InkWell(
                    onTap: _showQualitySelectionSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppTheme.cardLight,
                      child: Row(
                        children: [
                          const Icon(Icons.high_quality, size: 18, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  PdfService.getPresetLabel(_selectedQuality),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Est. size: ${PdfService.estimateFileSize(_pages.length, _selectedQuality)}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),

                  // Reorderable Grid / List of pages
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pages.length,
                      onReorder: _reorderPages,
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return Card(
                          key: ValueKey(page.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 50,
                                    height: 60,
                                    child: RotatedBox(
                                      quarterTurns: page.rotationDegrees ~/ 90,
                                      child: Image.file(
                                        File(page.currentPath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              'Page ${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              page.wasAutoCropped
                                  ? 'Auto-cropped document'
                                  : (page.isAdjusted ? 'Adjusted image' : 'Original photo'),
                              style: TextStyle(
                                color: page.wasAutoCropped || page.isAdjusted
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _openAdjustScreen(index),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Adjust Image',
                                  onPressed: () => _openAdjustScreen(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                                  tooltip: 'Remove Page',
                                  onPressed: () => _removePage(index),
                                ),
                                const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom bar with Add More & Generate buttons
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
                        OutlinedButton.icon(
                          onPressed: _showAddPagesSourceModal,
                          icon: const Icon(Icons.add),
                          label: const Text('Add More Pages'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _generatePdf,
                          child: _isGenerating
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text('Generate PDF (${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'})'),
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

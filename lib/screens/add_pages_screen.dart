import 'dart:io';
import 'package:flutter/material.dart';
import '../models/page_item.dart';
import '../services/entitlement_service.dart';
import '../services/image_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import 'fast_camera_capture_screen.dart';
import 'image_adjust_screen.dart';
import 'pdf_result_screen.dart';
import 'pro_screen.dart';

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
  final StorageService _storageService = StorageService();
  final UsageService _usageService = UsageService();
  final EntitlementService _entitlementService = EntitlementService();

  PdfQualityPreset _selectedQuality = PdfQualityPreset.standard;
  PdfPageOrientation _selectedOrientation = PdfPageOrientation.auto;
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

  void _showExportPdfSheet() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image page.')),
      );
      return;
    }

    final canCreate = _usageService.canCreatePdf(isProUser: _entitlementService.isProUser);
    if (!canCreate) {
      await ProScreen.showPaywall(context, isLimitPaywall: true);
      return;
    }

    final defaultFilename = await _storageService.generateFilename(DateTime.now());
    final defaultBaseName = defaultFilename.endsWith('.pdf')
        ? defaultFilename.substring(0, defaultFilename.length - 4)
        : defaultFilename;

    final filenameController = TextEditingController(text: defaultBaseName);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Export PDF Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filename Section
                      const Text(
                        'PDF Filename',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: filenameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter document name',
                          suffixText: '.pdf',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Orientation Section
                      const Text(
                        'Page Orientation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<PdfPageOrientation>(
                          segments: const [
                            ButtonSegment<PdfPageOrientation>(
                              value: PdfPageOrientation.auto,
                              label: Text('Auto'),
                              icon: Icon(Icons.auto_awesome, size: 16),
                            ),
                            ButtonSegment<PdfPageOrientation>(
                              value: PdfPageOrientation.portrait,
                              label: Text('Portrait'),
                              icon: Icon(Icons.crop_portrait, size: 16),
                            ),
                            ButtonSegment<PdfPageOrientation>(
                              value: PdfPageOrientation.landscape,
                              label: Text('Landscape'),
                              icon: Icon(Icons.crop_landscape, size: 16),
                            ),
                          ],
                          selected: {_selectedOrientation},
                          onSelectionChanged: (Set<PdfPageOrientation> newSelection) {
                            setSheetState(() => _selectedOrientation = newSelection.first);
                            setState(() => _selectedOrientation = newSelection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedOrientation == PdfPageOrientation.auto
                            ? 'Auto selects best orientation per page based on image aspect ratio.'
                            : (_selectedOrientation == PdfPageOrientation.portrait
                                ? 'Forces all pages into vertical A4 format.'
                                : 'Forces all pages into horizontal A4 format.'),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      // Quality Section
                      const Text(
                        'PDF Quality & Size',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      RadioListTile<PdfQualityPreset>(
                        value: PdfQualityPreset.standard,
                        groupValue: _selectedQuality,
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Standard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      RadioListTile<PdfQualityPreset>(
                        value: PdfQualityPreset.highQuality,
                        groupValue: _selectedQuality,
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            const Text('High Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            if (!_entitlementService.isProUser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'Maximum readability • Estimated: ${PdfService.estimateFileSize(_pages.length, PdfQualityPreset.highQuality)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (val) async {
                          if (val != null) {
                            if (!_entitlementService.isProUser) {
                              final unlocked = await ProScreen.showPaywall(context, isLimitPaywall: false);
                              if (unlocked == true || _entitlementService.isProUser) {
                                setSheetState(() => _selectedQuality = val);
                                setState(() => _selectedQuality = val);
                              }
                            } else {
                              setSheetState(() => _selectedQuality = val);
                              setState(() => _selectedQuality = val);
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handlePdfExport(filenameController.text);
                        },
                        child: Text('Generate PDF (${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'})'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handlePdfExport(String inputFilename) async {
    var sanitized = _storageService.sanitizeFilename(inputFilename);
    if (sanitized.isEmpty) {
      sanitized = await _storageService.generateFilename(DateTime.now());
    }

    bool overwrite = false;
    final fileExists = await _storageService.pdfFileExists(sanitized);

    if (fileExists && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('File Already Exists'),
          content: Text('A PDF named "$sanitized" already exists. How would you like to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'unique'),
              child: const Text('Keep Both (Auto-Rename)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );

      if (choice == 'cancel' || choice == null) {
        return;
      } else if (choice == 'overwrite') {
        overwrite = true;
      } else if (choice == 'unique') {
        sanitized = await _storageService.getUniqueFilename(sanitized);
      }
    }

    await _generatePdf(customFilename: sanitized, overwriteExisting: overwrite);
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

  Future<void> _generatePdf({String? customFilename, bool overwriteExisting = false}) async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image page.')),
      );
      return;
    }

    final canCreate = _usageService.canCreatePdf(isProUser: _entitlementService.isProUser);
    if (!canCreate) {
      await ProScreen.showPaywall(context, isLimitPaywall: true);
      return;
    }

    if (_selectedQuality == PdfQualityPreset.highQuality && !_entitlementService.isProUser) {
      final unlocked = await ProScreen.showPaywall(context, isLimitPaywall: false);
      if (unlocked != true && !_entitlementService.isProUser) {
        return;
      }
    }

    setState(() => _isGenerating = true);

    try {
      final pdfItem = await _pdfService.createPdf(
        pages: _pages,
        qualityPreset: _selectedQuality,
        orientation: _selectedOrientation,
        customFilename: customFilename,
        overwriteExisting: overwriteExisting,
      );

      await _usageService.recordSuccessfulPdfCreation(pdfId: pdfItem.id);

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
                  // Settings Selector Bar
                  InkWell(
                    onTap: _showExportPdfSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppTheme.cardLight,
                      child: Row(
                        children: [
                          const Icon(Icons.settings_outlined, size: 18, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${PdfService.getPresetLabel(_selectedQuality)} • ${PdfService.getOrientationLabel(_selectedOrientation)}',
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

                  // Reorderable List of pages
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

                  // Bottom bar with Add More & Export PDF buttons
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
                          onPressed: _isGenerating ? null : _showExportPdfSheet,
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

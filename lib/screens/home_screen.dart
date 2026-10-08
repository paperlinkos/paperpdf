import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pdf_item.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'add_pages_screen.dart';
import 'pdf_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  List<PdfItem> _recentPdfs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentPdfs();
  }

  Future<void> _loadRecentPdfs() async {
    setState(() => _isLoading = true);
    final pdfs = await _storageService.getRecentPdfs();
    if (mounted) {
      setState(() {
        _recentPdfs = pdfs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePdf(PdfItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: Text('Are you sure you want to delete "${item.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deletePdfItem(item.id);
      _loadRecentPdfs();
    }
  }

  void _openPdfResult(PdfItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfResultScreen(pdfItem: item),
      ),
    );
    _loadRecentPdfs();
  }

  void _openCreatePdf() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPagesScreen(),
      ),
    );
    _loadRecentPdfs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text('PaperLink PDF'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRecentPdfs,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecentPdfs,
          color: AppTheme.primaryGreen,
          child: Column(
            children: [
              // Header & Primary Action Hero Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Convert photos to PDF instantly.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select or take photos, adjust pages, and share directly to WhatsApp.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Primary Button: "Create PDF"
                    ElevatedButton.icon(
                      onPressed: _openCreatePdf,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text('Create PDF'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderLight),

              // Recent PDFs Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent PDFs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (_recentPdfs.isNotEmpty)
                      Text(
                        '${_recentPdfs.length} ${_recentPdfs.length == 1 ? 'file' : 'files'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Recent PDFs List / Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                      )
                    : _recentPdfs.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const SizedBox(height: 40),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.cardLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        size: 48,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No recent PDFs yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'PDFs created locally on your device will appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            itemCount: _recentPdfs.length,
                            itemBuilder: (context, index) {
                              final pdf = _recentPdfs[index];
                              final dateFormatted = DateFormat('MMM dd, yyyy • HH:mm').format(pdf.createdAt);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: Container(
                                    width: 44,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: pdf.thumbnailPath != null && File(pdf.thumbnailPath!).existsSync()
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: Image.file(
                                              File(pdf.thumbnailPath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.picture_as_pdf,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.picture_as_pdf,
                                            color: AppTheme.primaryGreen,
                                          ),
                                  ),
                                  title: Text(
                                    pdf.filename,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pdf.pageCount} ${pdf.pageCount == 1 ? 'page' : 'pages'} • ${pdf.formattedSize}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateFormatted,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openPdfResult(pdf),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                    onSelected: (val) {
                                      if (val == 'share') {
                                        ShareService.sharePdf(pdf.path, filename: pdf.filename);
                                      } else if (val == 'open') {
                                        ShareService.openPdf(pdf.path);
                                      } else if (val == 'delete') {
                                        _deletePdf(pdf);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share, size: 18),
                                            SizedBox(width: 8),
                                            Text('Share PDF'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'open',
                                        child: Row(
                                          children: [
                                            Icon(Icons.open_in_new, size: 18),
                                            SizedBox(width: 8),
                                            Text('Open External'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

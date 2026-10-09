import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pdf_item.dart';
import '../services/entitlement_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import 'add_pages_screen.dart';
import 'pdf_result_screen.dart';
import 'pro_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final UsageService _usageService = UsageService();
  final EntitlementService _entitlementService = EntitlementService();

  List<PdfItem> _recentPdfs = [];
  bool _isLoading = true;
  bool _showIntroBanner = true;

  @override
  void initState() {
    super.initState();
    _entitlementService.addListener(_onEntitlementUpdate);
    _initData();
  }

  @override
  void dispose() {
    _entitlementService.removeListener(_onEntitlementUpdate);
    super.dispose();
  }

  void _onEntitlementUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initData() async {
    await _usageService.init();
    final seen = await _storageService.hasSeenIntro();
    if (mounted) {
      setState(() {
        _showIntroBanner = !seen;
      });
    }
    await _loadRecentPdfs();
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

  Future<void> _dismissIntro() async {
    await _storageService.dismissIntro();
    if (mounted) {
      setState(() {
        _showIntroBanner = false;
      });
    }
  }

  Future<void> _renamePdf(PdfItem item) async {
    final baseName = item.filename.endsWith('.pdf')
        ? item.filename.substring(0, item.filename.length - 4)
        : item.filename;
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
            onPressed: () {
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      final updated = await _storageService.renamePdfItem(item.id, newName);
      if (updated != null) {
        _loadRecentPdfs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to ${updated.filename}')),
          );
        }
      }
    }
  }

  Future<void> _deletePdf(PdfItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: Text('Are you sure you want to permanently delete "${item.filename}"?'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF deleted from device.')),
        );
      }
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
    final canCreate = _usageService.canCreatePdf(isProUser: _entitlementService.isProUser);
    if (!canCreate) {
      await ProScreen.showPaywall(context, isLimitPaywall: true);
      setState(() {});
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPagesScreen(),
      ),
    );
    _loadRecentPdfs();
    setState(() {});
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
            icon: Icon(
              _entitlementService.isProUser ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              color: _entitlementService.isProUser ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
            tooltip: _entitlementService.isProUser ? 'PaperLink Pro (Active)' : 'Unlock PaperLink Pro',
            onPressed: () {
              ProScreen.showPaywall(context, isLimitPaywall: false);
            },
          ),
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
              // Lightweight First-Launch Introduction Banner
              if (_showIntroBanner)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Quick & Simple PDF Utility',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                            onPressed: _dismissIntro,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Turn photos or camera snaps into PDFs\n• Auto-crop & clean document pages\n• Share instantly via WhatsApp & native share',
                        style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

              // Unmistakable Hero Action Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Turn photos into clean PDFs instantly.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Usage status badge
                    if (_entitlementService.isProUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: AppTheme.primaryGreen),
                            SizedBox(width: 5),
                            Text(
                              'Pro • Unlimited PDFs',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => ProScreen.showPaywall(context, isLimitPaywall: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Free Plan: ${_usageService.getRemainingFreePdfs(isProUser: false)} of 5 left this month',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Primary Button: "Create PDF"
                    ElevatedButton.icon(
                      onPressed: _openCreatePdf,
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      label: const Text('Create PDF'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderLight),

              // Recent PDFs Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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

              // Recent PDFs List / Clean Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                      )
                    : _recentPdfs.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const SizedBox(height: 30),
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
                                      'No PDFs created yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap "Create PDF" above to convert your first document.',
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
                                        ShareService.sharePdf(
                                          pdf.path,
                                          filename: pdf.filename,
                                          context: context,
                                        );
                                      } else if (val == 'open') {
                                        ShareService.openPdf(pdf.path, context: context);
                                      } else if (val == 'rename') {
                                        _renamePdf(pdf);
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
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_note, size: 18),
                                            SizedBox(width: 8),
                                            Text('Rename'),
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

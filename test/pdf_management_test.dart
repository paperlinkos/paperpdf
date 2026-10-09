import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperlink_pdf/models/pdf_item.dart';
import 'package:paperlink_pdf/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;
  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paperlink_mgmt_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PDF Management & Renaming Tests', () {
    test('generateFilename formats default name correctly', () async {
      final storage = StorageService();
      final filename = await storage.generateFilename(DateTime(2026, 10, 8));
      expect(filename, startsWith('PaperLink_Document_2026-10-08_'));
      expect(filename, endsWith('.pdf'));
    });

    test('sanitizeFilename removes invalid characters and handles .pdf extension cleanly', () {
      final storage = StorageService();

      expect(storage.sanitizeFilename('My Invoice'), 'My Invoice.pdf');
      expect(storage.sanitizeFilename('My Invoice.pdf'), 'My Invoice.pdf');
      expect(storage.sanitizeFilename('My Invoice.PDF'), 'My Invoice.PDF');
      expect(storage.sanitizeFilename('My Invoice.pdf.pdf'), 'My Invoice.pdf');
      expect(storage.sanitizeFilename('Report: 2026/10? <test>*|'), 'Report_ 2026_10_ _test___.pdf');
      expect(storage.sanitizeFilename('   '), '');
    });

    test('pdfFileExists and getUniqueFilename resolve duplicate filenames', () async {
      final storage = StorageService();
      final pdfDir = await storage.getAppPdfDirectory();

      final file1 = File('${pdfDir.path}/Contract.pdf');
      await file1.writeAsString('contract content');

      expect(await storage.pdfFileExists('Contract.pdf'), isTrue);
      expect(await storage.pdfFileExists('Contract'), isTrue);
      expect(await storage.pdfFileExists('Contract.PDF'), isTrue);
      expect(await storage.pdfFileExists('NonExistent.pdf'), isFalse);

      final unique1 = await storage.getUniqueFilename('Contract.pdf');
      expect(unique1, 'Contract (1).pdf');

      final file2 = File('${pdfDir.path}/Contract (1).pdf');
      await file2.writeAsString('contract 1 content');

      final unique2 = await storage.getUniqueFilename('Contract');
      expect(unique2, 'Contract (2).pdf');
    });

    test('renamePdfItem renames physical file and updates metadata', () async {
      final storage = StorageService();
      final pdfDir = await storage.getAppPdfDirectory();

      final initialFile = File('${pdfDir.path}/PaperLink_Document_2026-10-08_001.pdf');
      await initialFile.writeAsString('dummy pdf data');

      final item = PdfItem(
        id: 'pdf-1',
        filename: 'PaperLink_Document_2026-10-08_001.pdf',
        path: initialFile.path,
        createdAt: DateTime.now(),
        pageCount: 2,
        fileSizeBytes: await initialFile.length(),
      );

      await storage.savePdfItem(item);

      final renamedItem = await storage.renamePdfItem('pdf-1', 'PaperLink_Receipt_2026-10-08.pdf');

      expect(renamedItem, isNotNull);
      expect(renamedItem!.filename, 'PaperLink_Receipt_2026-10-08.pdf');
      expect(File(renamedItem.path).existsSync(), isTrue);
      expect(File(initialFile.path).existsSync(), isFalse);

      final recent = await storage.getRecentPdfs();
      expect(recent.first.filename, 'PaperLink_Receipt_2026-10-08.pdf');
    });

    test('renamePdfItem resolves duplicate name by producing unique filename', () async {
      final storage = StorageService();
      final pdfDir = await storage.getAppPdfDirectory();

      final file1 = File('${pdfDir.path}/DocA.pdf');
      await file1.writeAsString('doc a');
      final file2 = File('${pdfDir.path}/DocB.pdf');
      await file2.writeAsString('doc b');

      final itemA = PdfItem(id: 'a', filename: 'DocA.pdf', path: file1.path, createdAt: DateTime.now(), pageCount: 1, fileSizeBytes: 5);
      final itemB = PdfItem(id: 'b', filename: 'DocB.pdf', path: file2.path, createdAt: DateTime.now(), pageCount: 1, fileSizeBytes: 5);

      await storage.savePdfItem(itemA);
      await storage.savePdfItem(itemB);

      final renamedB = await storage.renamePdfItem('b', 'DocA.pdf');
      expect(renamedB, isNotNull);
      expect(renamedB!.filename, 'DocA (1).pdf');
      expect(File(renamedB.path).existsSync(), isTrue);
    });

    test('deletePdfItem deletes physical file and metadata', () async {
      final storage = StorageService();
      final pdfDir = await storage.getAppPdfDirectory();

      final file = File('${pdfDir.path}/to_delete.pdf');
      await file.writeAsString('delete me');

      final item = PdfItem(
        id: 'pdf-del',
        filename: 'to_delete.pdf',
        path: file.path,
        createdAt: DateTime.now(),
        pageCount: 1,
        fileSizeBytes: await file.length(),
      );

      await storage.savePdfItem(item);
      expect((await storage.getRecentPdfs()).length, 1);

      await storage.deletePdfItem('pdf-del');
      expect((await storage.getRecentPdfs()).isEmpty, isTrue);
      expect(file.existsSync(), isFalse);
    });
  });
}

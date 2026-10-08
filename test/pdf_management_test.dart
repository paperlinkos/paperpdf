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

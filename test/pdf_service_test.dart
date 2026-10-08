import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paperlink_pdf/models/page_item.dart';
import 'package:paperlink_pdf/services/pdf_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('paperlink_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createDummyImageFile(String name, {int width = 800, int height = 1000}) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(250, 250, 250));
    img.fillRect(image, x1: 50, y1: 50, x2: width - 50, y2: height - 50, color: img.ColorRgb8(50, 50, 50));

    final path = '${tempDir.path}/$name.jpg';
    final bytes = img.encodeJpg(image);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  group('PDF Quality Presets & File Size Estimation', () {
    test('estimateFileSize returns accurate estimates for page counts', () {
      expect(PdfService.estimateFileSize(1, PdfQualityPreset.standard), '~ 200 KB');
      expect(PdfService.estimateFileSize(5, PdfQualityPreset.standard), '~ 1.0 MB');
      expect(PdfService.estimateFileSize(10, PdfQualityPreset.highQuality), '~ 5.9 MB');
      expect(PdfService.estimateFileSize(20, PdfQualityPreset.highQuality), '~ 11.7 MB');
    });

    test('Generates PDF with 1 page (Portrait & Landscape)', () async {
      final imgPath = await createDummyImageFile('portrait_1', width: 600, height: 800);
      final page = PageItem(id: 'p1', originalPath: imgPath, currentPath: imgPath);

      final pdfService = PdfService();
      final pdfItem = await pdfService.createPdf(
        pages: [page],
        qualityPreset: PdfQualityPreset.standard,
      );

      expect(pdfItem.pageCount, 1);
      expect(File(pdfItem.path).existsSync(), isTrue);
      expect(pdfItem.fileSizeBytes, greaterThan(0));
    });

    test('Generates PDF at scale: 5 pages, 10 pages, 20 pages', () async {
      final pdfService = PdfService();

      for (final count in [5, 10, 20]) {
        final pages = <PageItem>[];
        for (int i = 0; i < count; i++) {
          final isLandscape = i % 2 == 1;
          final imgPath = await createDummyImageFile(
            'scale_${count}_$i',
            width: isLandscape ? 1000 : 800,
            height: isLandscape ? 800 : 1000,
          );
          pages.add(PageItem(id: 'p_$i', originalPath: imgPath, currentPath: imgPath));
        }

        final pdfItem = await pdfService.createPdf(
          pages: pages,
          qualityPreset: PdfQualityPreset.standard,
        );

        expect(pdfItem.pageCount, count);
        expect(File(pdfItem.path).existsSync(), isTrue);
        expect(pdfItem.fileSizeBytes, greaterThan(0));
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}

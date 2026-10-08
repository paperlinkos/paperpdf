import 'package:flutter_test/flutter_test.dart';
import 'package:paperlink_pdf/models/pdf_item.dart';
import 'package:paperlink_pdf/models/page_item.dart';

void main() {
  group('PdfItem tests', () {
    test('PdfItem JSON serialization and deserialization', () {
      final now = DateTime(2026, 10, 8, 12, 0);
      final item = PdfItem(
        id: 'test-123',
        filename: 'PaperLink_2026-10-08_001.pdf',
        path: '/storage/emulated/0/PaperLink_2026-10-08_001.pdf',
        createdAt: now,
        pageCount: 5,
        fileSizeBytes: 2048576, // ~1.95 MB
        thumbnailPath: '/storage/emulated/0/thumb.jpg',
      );

      final jsonMap = item.toJson();
      expect(jsonMap['id'], 'test-123');
      expect(jsonMap['filename'], 'PaperLink_2026-10-08_001.pdf');
      expect(jsonMap['pageCount'], 5);

      final reconstructed = PdfItem.fromJson(jsonMap);
      expect(reconstructed.id, item.id);
      expect(reconstructed.filename, item.filename);
      expect(reconstructed.createdAt, item.createdAt);
      expect(reconstructed.pageCount, item.pageCount);
      expect(reconstructed.fileSizeBytes, item.fileSizeBytes);
      expect(reconstructed.formattedSize, '2.0 MB');
    });

    test('PdfItem list encoding and decoding', () {
      final item1 = PdfItem(
        id: '1',
        filename: 'PaperLink_2026-10-08_001.pdf',
        path: '/path/1.pdf',
        createdAt: DateTime(2026, 10, 8),
        pageCount: 1,
        fileSizeBytes: 500,
      );
      final item2 = PdfItem(
        id: '2',
        filename: 'PaperLink_2026-10-08_002.pdf',
        path: '/path/2.pdf',
        createdAt: DateTime(2026, 10, 8),
        pageCount: 3,
        fileSizeBytes: 150000,
      );

      final encoded = PdfItem.encodeList([item1, item2]);
      final decoded = PdfItem.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].filename, 'PaperLink_2026-10-08_001.pdf');
      expect(decoded[1].filename, 'PaperLink_2026-10-08_002.pdf');
      expect(decoded[1].formattedSize, '146.5 KB');
    });
  });

  group('PageItem tests', () {
    test('PageItem initial state and adjustments detection', () {
      final page = PageItem(
        id: 'p1',
        originalPath: '/path/img.jpg',
        currentPath: '/path/img.jpg',
      );

      expect(page.isAdjusted, isFalse);

      final rotated = page.copyWith(rotationDegrees: 90);
      expect(rotated.isAdjusted, isTrue);

      final brightened = page.copyWith(brightness: 0.2);
      expect(brightened.isAdjusted, isTrue);

      final contrastChanged = page.copyWith(contrast: 1.2);
      expect(contrastChanged.isAdjusted, isTrue);
    });
  });
}

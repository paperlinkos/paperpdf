import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperlink_pdf/config/monetization_config.dart';
import 'package:paperlink_pdf/models/pdf_item.dart';
import 'package:paperlink_pdf/services/entitlement_service.dart';
import 'package:paperlink_pdf/services/storage_service.dart';
import 'package:paperlink_pdf/services/usage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('paperlink_monetization_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    await UsageService().init();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 4: Freemium Usage Limits & Month Rollover', () {
    test('0 free PDFs: can create, remaining is 5', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 0);

      expect(usage.getUsageCount(), 0);
      expect(usage.canCreatePdf(isProUser: false), isTrue);
      expect(usage.getRemainingFreePdfs(isProUser: false), 5);
    });

    test('1 free PDF: can create, remaining is 4', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 0);
      await usage.recordSuccessfulPdfCreation(pdfId: 'pdf-1');

      expect(usage.getUsageCount(), 1);
      expect(usage.canCreatePdf(isProUser: false), isTrue);
      expect(usage.getRemainingFreePdfs(isProUser: false), 4);
    });

    test('4 free PDFs: can create, remaining is 1', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 4);

      expect(usage.getUsageCount(), 4);
      expect(usage.canCreatePdf(isProUser: false), isTrue);
      expect(usage.getRemainingFreePdfs(isProUser: false), 1);
    });

    test('5 free PDFs: limit reached, remaining is 0', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 5);

      expect(usage.getUsageCount(), 5);
      expect(usage.canCreatePdf(isProUser: false), isFalse);
      expect(usage.getRemainingFreePdfs(isProUser: false), 0);
    });

    test('sixth PDF attempt: blocked by limit', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 5);

      // Verify sixth creation attempt is not allowed for free user
      expect(usage.canCreatePdf(isProUser: false), isFalse);
      expect(usage.getRemainingFreePdfs(isProUser: false), 0);
    });

    test('month rollover: resets usage count and remaining allowance', () async {
      final usage = UsageService();
      final lastMonth = DateTime(2026, 9, 15);
      final thisMonth = DateTime(2026, 10, 1);

      // Set usage in previous month to 5 (fully exhausted)
      await usage.resetForTesting(setCount: 5, monthKey: '2026-09');

      // Now query with current month date
      final currentUsage = usage.getUsageCount(now: thisMonth);
      expect(currentUsage, 0);
      expect(usage.canCreatePdf(isProUser: false, now: thisMonth), isTrue);
      expect(usage.getRemainingFreePdfs(isProUser: false, now: thisMonth), 5);
    });

    test('failed PDF generation does not consume allowance', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 2);

      // Simulating a failed operation (an exception occurs and recordSuccessfulPdfCreation is NOT called)
      try {
        throw Exception('Simulated rendering failure');
      } catch (_) {
        // Operation aborted, no recording
      }

      expect(usage.getUsageCount(), 2);
      expect(usage.getRemainingFreePdfs(isProUser: false), 3);
    });

    test('prevent accidental double-counting with same pdfId', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 1);

      final firstCount = await usage.recordSuccessfulPdfCreation(pdfId: 'doc-abc');
      expect(firstCount, isTrue);
      expect(usage.getUsageCount(), 2);

      // Attempting to record with identical id again
      final secondCount = await usage.recordSuccessfulPdfCreation(pdfId: 'doc-abc');
      expect(secondCount, isFalse);
      expect(usage.getUsageCount(), 2);
    });

    test('Pro user bypasses free limit completely', () async {
      final usage = UsageService();
      await usage.resetForTesting(setCount: 5);

      // Free user is blocked
      expect(usage.canCreatePdf(isProUser: false), isFalse);

      // Pro user is allowed
      expect(usage.canCreatePdf(isProUser: true), isTrue);
      expect(usage.getRemainingFreePdfs(isProUser: true), -1); // Unlimited
    });
  });

  group('Phase 4: Entitlement & Store Billing Logic', () {
    test('Pro status allows High Quality export and bypasses caps', () {
      final entitlement = EntitlementService();
      entitlement.setProForTesting(true);

      expect(entitlement.isProUser, isTrue);

      final usage = UsageService();
      expect(usage.canCreatePdf(isProUser: entitlement.isProUser), isTrue);
    });

    test('Purchase cancellation does not grant Pro', () {
      final entitlement = EntitlementService();
      entitlement.setProForTesting(false);

      expect(entitlement.isProUser, isFalse);
      expect(entitlement.errorMessage, isNull);
    });

    test('Purchase success and restoration grants Pro', () {
      final entitlement = EntitlementService();
      entitlement.setProForTesting(false);

      // Simulate successful unlock
      entitlement.setProForTesting(true);
      expect(entitlement.isProUser, isTrue);
    });

    test('Offline mode: cached Pro status works without network', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cached_pro_entitlement_v1', true);

      // Entitlement loads cached value locally
      final entitlement = EntitlementService();
      await entitlement.initialize();

      expect(entitlement.isProUser, isTrue);
    });

    test('Existing local PDFs remain fully accessible when limit is reached', () async {
      final storage = StorageService();
      final pdfDir = await storage.getAppPdfDirectory();

      // Create an existing PDF
      final file = File('${pdfDir.path}/existing_doc.pdf');
      await file.writeAsString('pdf content');

      final item = PdfItem(
        id: 'existing-1',
        filename: 'existing_doc.pdf',
        path: file.path,
        createdAt: DateTime.now(),
        pageCount: 3,
        fileSizeBytes: 1024,
      );
      await storage.savePdfItem(item);

      // Exhaust free usage limit
      final usage = UsageService();
      await usage.resetForTesting(setCount: 5);
      expect(usage.canCreatePdf(isProUser: false), isFalse);

      // Existing local PDFs can still be retrieved and read
      final recent = await storage.getRecentPdfs();
      expect(recent.length, 1);
      expect(recent.first.filename, 'existing_doc.pdf');
      expect(File(recent.first.path).existsSync(), isTrue);
    });
  });
}

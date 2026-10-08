import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/monetization_config.dart';

class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const String _prefUsageMonthKey = 'usage_calendar_month_key';
  static const String _prefUsageCountKey = 'usage_monthly_pdf_count';
  static const String _prefLastCountedIdKey = 'usage_last_counted_pdf_id';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _getMonthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  /// Returns current month's usage count, auto-resetting if a new calendar month has begun.
  int getUsageCount({DateTime? now}) {
    final prefs = _prefs;
    if (prefs == null) return 0;

    final currentDate = now ?? DateTime.now();
    final currentMonthKey = _getMonthKey(currentDate);
    final storedMonthKey = prefs.getString(_prefUsageMonthKey);

    if (storedMonthKey == null || storedMonthKey != currentMonthKey) {
      // Month rollover: Reset count to 0 for the new month
      prefs.setString(_prefUsageMonthKey, currentMonthKey);
      prefs.setInt(_prefUsageCountKey, 0);
      prefs.remove(_prefLastCountedIdKey);
      return 0;
    }

    return prefs.getInt(_prefUsageCountKey) ?? 0;
  }

  /// Whether the user is allowed to generate another PDF.
  /// Pro users are always allowed. Free users are limited to 5 per month.
  bool canCreatePdf({required bool isProUser, DateTime? now}) {
    if (isProUser) return true;
    final count = getUsageCount(now: now);
    return count < MonetizationConfig.freePdfLimitPerMonth;
  }

  /// Number of free PDFs remaining for this calendar month.
  /// Returns -1 if user is Pro (unlimited).
  int getRemainingFreePdfs({required bool isProUser, DateTime? now}) {
    if (isProUser) return -1;
    final count = getUsageCount(now: now);
    final remaining = MonetizationConfig.freePdfLimitPerMonth - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// Records a successful PDF creation for usage tracking.
  /// `pdfId` is used to prevent accidental double-counting of the same generation.
  Future<bool> recordSuccessfulPdfCreation({required String pdfId, DateTime? now}) async {
    await init();
    final prefs = _prefs!;

    final lastCountedId = prefs.getString(_prefLastCountedIdKey);
    if (lastCountedId == pdfId) {
      // Prevent accidental double-counting
      return false;
    }

    final currentDate = now ?? DateTime.now();
    final currentMonthKey = _getMonthKey(currentDate);
    final storedMonthKey = prefs.getString(_prefUsageMonthKey);

    int count = 0;
    if (storedMonthKey == currentMonthKey) {
      count = prefs.getInt(_prefUsageCountKey) ?? 0;
    } else {
      await prefs.setString(_prefUsageMonthKey, currentMonthKey);
    }

    count += 1;
    await prefs.setInt(_prefUsageCountKey, count);
    await prefs.setString(_prefLastCountedIdKey, pdfId);

    debugPrint('Recorded PDF creation: $count / ${MonetizationConfig.freePdfLimitPerMonth} for month $currentMonthKey');
    return true;
  }

  /// Testing helper: Reset usage
  @visibleForTesting
  Future<void> resetForTesting({int setCount = 0, String? monthKey}) async {
    await init();
    final prefs = _prefs!;
    await prefs.setString(_prefUsageMonthKey, monthKey ?? _getMonthKey(DateTime.now()));
    await prefs.setInt(_prefUsageCountKey, setCount);
    await prefs.remove(_prefLastCountedIdKey);
  }
}

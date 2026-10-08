class MonetizationConfig {
  /// Product identifier for the one-time lifetime Pro unlock
  static const String proLifetimeProductId = 'paperlink_pro_lifetime';

  /// Fallback display price if Google Play details are not yet loaded or offline
  static const String defaultProPriceDisplay = '₦7,500 once';

  /// Number of free PDF creations allowed per calendar month
  static const int freePdfLimitPerMonth = 5;

  /// Factual Pro features list
  static const List<String> proFeatures = [
    'Unlimited PDF creations',
    'High Quality PDF export',
    'Batch multi-page processing',
    'Future Pro features included',
  ];
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/monetization_config.dart';

enum BillingStatus {
  idle,
  loading,
  purchasing,
  restoring,
  success,
  cancelled,
  error,
}

class EntitlementService extends ChangeNotifier {
  static final EntitlementService _instance = EntitlementService._internal();
  factory EntitlementService() => _instance;
  EntitlementService._internal();

  static const String _prefProCachedKey = 'cached_pro_entitlement_v1';

  InAppPurchase? _customIap;

  @visibleForTesting
  set iapInstance(InAppPurchase? iap) => _customIap = iap;

  InAppPurchase? get _iap {
    if (_customIap != null) return _customIap;
    try {
      return InAppPurchase.instance;
    } catch (e) {
      debugPrint('InAppPurchase platform channel unavailable: $e');
      return null;
    }
  }

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isProUser = false;
  bool _isBillingAvailable = false;
  BillingStatus _status = BillingStatus.idle;
  String? _errorMessage;
  ProductDetails? _proProductDetails;

  bool get isProUser => _isProUser;
  bool get isBillingAvailable => _isBillingAvailable;
  BillingStatus get status => _status;
  String? get errorMessage => _errorMessage;
  ProductDetails? get proProductDetails => _proProductDetails;

  /// Human-readable price (uses Google Play localized price if available, fallback otherwise)
  String get proPriceFormatted =>
      _proProductDetails?.price.isNotEmpty == true
          ? '${_proProductDetails!.price} once'
          : MonetizationConfig.defaultProPriceDisplay;

  Future<void> initialize() async {
    // 1. Load local cache to avoid UI flicker
    await _loadCachedEntitlement();

    final iap = _iap;
    if (iap == null) {
      _isBillingAvailable = false;
      notifyListeners();
      return;
    }

    // 2. Listen to purchase updates stream
    try {
      _subscription = iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('Billing purchaseStream error: $error');
          _status = BillingStatus.error;
          _errorMessage = 'Billing service encountered an error. Please try again.';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Billing purchaseStream unavailable in current environment: $e');
    }

    // 3. Check store availability
    try {
      _isBillingAvailable = await iap.isAvailable();
      if (_isBillingAvailable) {
        await _fetchProductDetails();
      } else {
        debugPrint('Google Play Billing is not currently available on this device.');
      }
    } catch (e) {
      debugPrint('Error initializing in_app_purchase: $e');
      _isBillingAvailable = false;
    }

    notifyListeners();
  }

  Future<void> _loadCachedEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isProUser = prefs.getBool(_prefProCachedKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached entitlement: $e');
    }
  }

  Future<void> _updateCachedEntitlement(bool isPro) async {
    _isProUser = isPro;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefProCachedKey, isPro);
    } catch (e) {
      debugPrint('Error saving cached entitlement: $e');
    }
    notifyListeners();
  }

  Future<void> _fetchProductDetails() async {
    final iap = _iap;
    if (iap == null) return;
    try {
      final response = await iap.queryProductDetails({MonetizationConfig.proLifetimeProductId});
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found in store: ${response.notFoundIDs}');
      }
      if (response.productDetails.isNotEmpty) {
        _proProductDetails = response.productDetails.firstWhere(
          (p) => p.id == MonetizationConfig.proLifetimeProductId,
          orElse: () => response.productDetails.first,
        );
      }
    } catch (e) {
      debugPrint('Failed to query product details: $e');
    }
  }

  /// Initiates purchase of the lifetime Pro unlock
  Future<bool> buyPro() async {
    final iap = _iap;
    if (iap == null || !_isBillingAvailable) {
      _status = BillingStatus.error;
      _errorMessage = 'Google Play Store is currently unavailable. Please check your network or try again later.';
      notifyListeners();
      return false;
    }

    _status = BillingStatus.purchasing;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_proProductDetails == null) {
        await _fetchProductDetails();
      }

      final product = _proProductDetails;
      if (product == null) {
        _status = BillingStatus.error;
        _errorMessage = 'Pro product details could not be loaded from Google Play.';
        notifyListeners();
        return false;
      }

      final purchaseParam = PurchaseParam(productDetails: product);
      return await iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error initiating buyPro: $e');
      _status = BillingStatus.error;
      _errorMessage = 'Failed to launch Google Play purchase. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    final iap = _iap;
    if (iap == null || !_isBillingAvailable) {
      _status = BillingStatus.error;
      _errorMessage = 'Google Play Store is unavailable. Please check your internet connection.';
      notifyListeners();
      return;
    }

    _status = BillingStatus.restoring;
    _errorMessage = null;
    notifyListeners();

    try {
      await iap.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      _status = BillingStatus.error;
      _errorMessage = 'Could not restore purchases from Google Play. Please try again.';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    final iap = _iap;
    for (final purchase in purchaseDetailsList) {
      if (purchase.productID != MonetizationConfig.proLifetimeProductId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _status = BillingStatus.purchasing;
          _errorMessage = null;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase && iap != null) {
            await iap.completePurchase(purchase);
          }
          await _updateCachedEntitlement(true);
          _status = BillingStatus.success;
          _errorMessage = null;
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _status = BillingStatus.cancelled;
          _errorMessage = null;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _status = BillingStatus.error;
          // Provide clean, human-understandable message without raw exception codes
          final errorMsg = purchase.error?.message;
          if (errorMsg != null && errorMsg.toLowerCase().contains('already')) {
            // Already owned
            await _updateCachedEntitlement(true);
            _status = BillingStatus.success;
            _errorMessage = 'PaperLink Pro has been restored!';
          } else {
            _errorMessage = 'Purchase could not be completed. You have not been charged.';
          }
          notifyListeners();
          break;
      }
    }
  }

  /// Testing helper to set Pro status directly in unit tests
  @visibleForTesting
  void setProForTesting(bool isPro) {
    _isProUser = isPro;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

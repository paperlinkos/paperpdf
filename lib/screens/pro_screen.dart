import 'package:flutter/material.dart';
import '../config/monetization_config.dart';
import '../services/entitlement_service.dart';
import '../theme/app_theme.dart';

class ProScreen extends StatefulWidget {
  final bool isLimitPaywall;

  const ProScreen({
    super.key,
    this.isLimitPaywall = false,
  });

  /// Displays the paywall as a modal bottom sheet or dialog
  static Future<bool?> showPaywall(BuildContext context, {bool isLimitPaywall = true}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProScreen(isLimitPaywall: isLimitPaywall),
    );
  }

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final EntitlementService _entitlementService = EntitlementService();

  @override
  void initState() {
    super.initState();
    _entitlementService.addListener(_onBillingUpdate);
  }

  @override
  void dispose() {
    _entitlementService.removeListener(_onBillingUpdate);
    super.dispose();
  }

  void _onBillingUpdate() {
    if (!mounted) return;

    if (_entitlementService.status == BillingStatus.success && _entitlementService.isProUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 PaperLink Pro is now unlocked! Enjoy unlimited PDFs.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context, true);
    } else if (_entitlementService.errorMessage != null &&
        _entitlementService.status == BillingStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_entitlementService.errorMessage!),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _handleBuyPro() async {
    await _entitlementService.buyPro();
  }

  Future<void> _handleRestore() async {
    await _entitlementService.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _entitlementService.status == BillingStatus.purchasing ||
        _entitlementService.status == BillingStatus.restoring;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Limit Paywall Banner if triggered by monthly cap
              if (widget.isLimitPaywall) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You've used your 5 free PDFs this month.",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Header Branding Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 40,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'PaperLink Pro',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One-time purchase • No recurring subscriptions',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Features List
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: MonetizationConfig.proFeatures.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Price Display
              Text(
                _entitlementService.proPriceFormatted,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Primary Action: Unlock Pro
              ElevatedButton(
                onPressed: isLoading ? null : _handleBuyPro,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(widget.isLimitPaywall ? 'Unlock PaperLink Pro' : 'Unlock Pro'),
              ),
              const SizedBox(height: 12),

              // Secondary Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : _handleRestore,
                    child: const Text(
                      'Restore Purchase',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isLimitPaywall) ...[
                    const Text(' • ', style: TextStyle(color: AppTheme.borderLight)),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

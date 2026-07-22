import 'dart:async';
import 'dart:math' as math;

import 'package:contact_photos/services/analytics_service.dart';
import 'package:contact_photos/services/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  /// Shows the paywall as a modal bottom sheet.
  /// Returns `true` if the purchase was completed or restored, `false` otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GlassSheet(
          settings: LiquidGlassSettings(
            blur: 12,
            thickness: 5,
            ambientStrength: 0.5,
            lightIntensity: 0.6,
            lightAngle: 0.75 * math.pi,
            glassColor: Colors.white.withValues(alpha: 0.12),
          ),
          child: const PaywallScreen()),
    );
    return result ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  String _priceLabel = r'$1.99';
  StreamSubscription<PurchaseDetails>? _purchaseSubscription;
  StreamSubscription<String>? _streamErrorSubscription;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
    _purchaseSubscription = PurchaseService.instance.purchaseStream.listen(
      _onPurchaseUpdate,
    );
    _streamErrorSubscription =
        PurchaseService.instance.streamErrorStream.listen((message) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = message;
      });
    });
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _streamErrorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProductDetails() async {
    final product = await PurchaseService.instance.fetchProductDetails();
    if (mounted && product != null) {
      setState(() {
        _priceLabel = product.price;
      });
    }
  }

  void _onPurchaseUpdate(PurchaseDetails details) {
    if (!mounted) return;
    if (details.status == PurchaseStatus.purchased ||
        details.status == PurchaseStatus.restored) {
      Navigator.of(context).pop(true);
      return;
    }
    if (details.status == PurchaseStatus.error) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            details.error?.message ?? 'Purchase failed. Please try again.';
      });
      return;
    }
    if (details.status == PurchaseStatus.canceled) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Purchase canceled.';
      });
      return;
    }
    if (details.status == PurchaseStatus.pending) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });
    }
  }

  Future<void> _onUnlockPressed() async {
    unawaited(AnalyticsService.creationPagePaywallUnlockTapped());
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    final started = await PurchaseService.instance.purchase();
    if (!started && mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Product unavailable. Please try again later.';
      });
    }
  }

  Future<void> _onRestorePressed() async {
    unawaited(AnalyticsService.creationPagePaywallRestoreTapped());
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    final wasRestored = await PurchaseService.instance.restorePurchases();
    // If a purchase was restored, _onPurchaseUpdate already popped the sheet.
    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
        _statusMessage = wasRestored
            ? 'Purchase restored successfully!'
            : 'No previous purchase found for this Apple ID.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unlock Unlimited Contacts',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You have used your 3 free contact creations.\n\n'
              'Purchase once to create unlimited contacts and keep all your '
              'business contacts looking great.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton(
                onPressed: _onUnlockPressed,
                child: Text('Unlock — $_priceLabel'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onRestorePressed,
                child: const Text('Restore Purchases'),
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                unawaited(
                    AnalyticsService.creationPagePaywallDialogCancelTapped());
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

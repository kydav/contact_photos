import 'dart:async';

import 'package:contact_photos/services/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  /// Shows the paywall as a modal bottom sheet.
  /// Returns `true` if the purchase was completed or restored, `false` otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaywallScreen(),
    );
    return result ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  String _priceLabel = r'$0.99';
  StreamSubscription<PurchaseDetails>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
    _purchaseSubscription = PurchaseService.instance.purchaseStream.listen(
      _onPurchaseUpdate,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
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
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    final started = await PurchaseService.instance.purchase();
    if (!started && mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'Product unavailable. Please try again later.';
      });
    }
  }

  Future<void> _onRestorePressed() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    await PurchaseService.instance.restorePurchases();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Restore complete. If you have a prior purchase it will be applied.';
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

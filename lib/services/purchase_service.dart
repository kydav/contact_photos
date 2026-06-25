import 'dart:async';

import 'package:contact_photos/services/preferences_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static const productId = 'contact_photos_lifetime';

  PurchaseService._();
  static final instance = PurchaseService._();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();
  final _streamErrorController = StreamController<String>.broadcast();

  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  /// Fires when the underlying IAP stream itself errors (distinct from a failed
  /// purchase, which arrives as PurchaseStatus.error via purchaseStream).
  Stream<String> get streamErrorStream => _streamErrorController.stream;

  void initialize() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (Object error) {
        _streamErrorController.add(
          'Payment system error. Please restart the app and try again.',
        );
      },
    );
  }

  Future<void> _handlePurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final details in purchaseDetailsList) {
      if (details.status == PurchaseStatus.purchased ||
          details.status == PurchaseStatus.restored) {
        await PreferencesService.setPurchaseUnlocked();
      }
      if (details.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(details);
      }
      _purchaseController.add(details);
    }
  }

  Future<ProductDetails?> fetchProductDetails() async {
    final response =
        await InAppPurchase.instance.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  Future<bool> purchase() async {
    final product = await fetchProductDetails();
    if (product == null) {
      return false;
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    return true;
  }

  /// Initiates a restore and resolves with whether at least one purchase was
  /// restored within [timeout]. Callers that need the entitlement outcome
  /// should listen to [purchaseStream] for [PurchaseStatus.restored] events.
  Future<bool> restorePurchases({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    var restored = false;

    final completer = Completer<bool>();
    late StreamSubscription<PurchaseDetails> sub;

    sub = purchaseStream.listen((details) {
      if (details.status == PurchaseStatus.restored) {
        restored = true;
        if (!completer.isCompleted) completer.complete(true);
      } else if (details.status == PurchaseStatus.error) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    await InAppPurchase.instance.restorePurchases();

    // Give the store time to deliver all restored transactions.
    await completer.future
        .timeout(timeout, onTimeout: () => restored)
        .whenComplete(sub.cancel);

    return restored;
  }
}

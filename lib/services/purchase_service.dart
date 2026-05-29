import 'dart:async';

import 'package:contact_photos/services/preferences_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static const productId = 'unlimited_contacts';

  PurchaseService._();
  static final instance = PurchaseService._();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();

  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  void initialize() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
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
    final response = await InAppPurchase.instance.queryProductDetails({productId});
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

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }
}

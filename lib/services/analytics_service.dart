import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;

  // ── Intro ──────────────────────────────────────────────────────────────────

  static Future<void> introNextTapped() =>
      _log('intro_nextTapped');

  static Future<void> introFinishedIntro({required bool allowedAccess}) =>
      _log('intro_finishedIntro', p: {'allowed_access': allowedAccess});

  // ── Search page ────────────────────────────────────────────────────────────

  static Future<void> searchPageSearched({required String name}) =>
      _log('searchPage_searched', p: {'name': name});

  static Future<void> searchPageSelectedCompanyResult({
    required String name,
    required String url,
  }) =>
      _log('searchPage_selectedCompanyResult', p: {'name': name, 'url': url});

  static Future<void> searchPageEnteredManualUrlButtonTapped() =>
      _log('searchPage_enteredManualUrlButtonTapped');

  static Future<void> searchPageEnteredManualUrlDialogClosed() =>
      _log('searchPage_enteredManualUrlDialogClosed');

  static Future<void> searchPageEnteredManualUrlDialogSaved({
    required String url,
  }) =>
      _log('searchPage_enteredManualUrlDialogSaved', p: {'url': url});

  // ── Image page ─────────────────────────────────────────────────────────────

  static Future<void> imagePageQueriedImages({required int count}) =>
      _log('imagePage_queriedImages', p: {'count': count});

  static Future<void> imagePageSelectedImage({required String imageUrl}) =>
      _log('imagePage_selectedImage', p: {'image_url': imageUrl});

  static Future<void> imagePageUploadManualImageButtonTapped() =>
      _log('imagePage_uploadManualImageButtonTapped');

  // Shortened from imagePage_uploadManualImageChooseImageTapped (44 chars > 40 limit)
  static Future<void> imagePageUploadChooseImageTapped() =>
      _log('imagePage_uploadChooseImageTapped');

  static Future<void> imagePageUploadManualImageImageChosen() =>
      _log('imagePage_uploadManualImageImageChosen');

  // ── Creation page ──────────────────────────────────────────────────────────

  static Future<void> creationPageCropTapped() =>
      _log('creationPage_cropTapped');

  static Future<void> creationPageEditContactNameTapped() =>
      _log('creationPage_editContactNameTapped');

  static Future<void> creationPageEditContactNameDialogSaved({
    required String name,
  }) =>
      _log('creationPage_editContactNameDialogSaved', p: {'name': name});

  static Future<void> creationPageCreateContactButtonTapped({
    required bool successful,
  }) =>
      _log('creationPage_createContactButtonTapped',
          p: {'successful': successful});

  static Future<void> creationPagePaywallDialogShown() =>
      _log('creationPage_paywallDialogShown');

  // Shortened from creationPage_paywallRestorePurchasesTapped (42 chars > 40 limit)
  static Future<void> creationPagePaywallRestoreTapped() =>
      _log('creationPage_paywallRestoreTapped');

  static Future<void> creationPagePaywallDialogCancelTapped() =>
      _log('creationPage_paywallDialogCancelTapped');

  static Future<void> creationPagePaywallUnlockTapped() =>
      _log('creationPage_paywallUnlockTapped');

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<void> _log(String name,
      {Map<String, Object>? p}) =>
      _analytics.logEvent(name: name, parameters: p);
}

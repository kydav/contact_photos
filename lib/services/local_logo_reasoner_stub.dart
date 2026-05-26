class LocalLogoReasoner {
  static bool get isConfigured => false;

  static Future<List<String>> suggestLogoUrls({
    required String companyName,
    required String companyWebsiteUrl,
    Iterable<String> existingUrls = const [],
  }) async {
    return [];
  }
}

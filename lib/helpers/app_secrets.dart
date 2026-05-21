class AppSecrets {
  static const String logokitApiKey = String.fromEnvironment(
    'LOGOKIT_API_KEY',
  );

  static bool get hasLogokitApiKey => logokitApiKey.isNotEmpty;
}

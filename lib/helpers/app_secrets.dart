class AppSecrets {
  static const String logokitApiKey = String.fromEnvironment(
    'LOGOKIT_API_KEY',
  );

  static bool get hasLogokitApiKey => logokitApiKey.isNotEmpty;

  static const bool enableLocalLlamaLogoFallback = bool.fromEnvironment(
    'ENABLE_LOCAL_LLAMA_LOGO_FALLBACK',
  );

  static const String llamaModelPath = String.fromEnvironment(
    'LLAMA_MODEL_PATH',
  );

  static const String llamaLibraryPath = String.fromEnvironment(
    'LLAMA_LIBRARY_PATH',
  );

  static const String llamaChatFormat = String.fromEnvironment(
    'LLAMA_CHAT_FORMAT',
    defaultValue: 'gemma',
  );

  static const int llamaContextTokens = int.fromEnvironment(
    'LLAMA_CONTEXT_TOKENS',
    defaultValue: 4096,
  );

  static const int llamaPredictTokens = int.fromEnvironment(
    'LLAMA_PREDICT_TOKENS',
    defaultValue: 512,
  );

  static const int llamaThreads = int.fromEnvironment(
    'LLAMA_THREADS',
    defaultValue: 4,
  );

  static const int llamaGpuLayers = int.fromEnvironment(
    'LLAMA_GPU_LAYERS',
  );

  static bool get hasLocalLlamaLogoFallback =>
      enableLocalLlamaLogoFallback && llamaModelPath.isNotEmpty;
}

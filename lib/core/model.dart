enum ModelType {
  general,
  gemmaIt,
  deepSeek,
  /// Gemma 3n E2B model with audio and vision support
  gemma3nE2B,
  /// Gemma 3n E4B model with audio and vision support  
  gemma3nE4B,
  /// Gemma 3 1B model (text-only, optimized for on-device)
  gemma3_1B,
}
class Config {
  // GCP Cloud Run OmniScribe Backend URL (Amsterdam, Europe - europe-west4)
  static const String backendUrl = "https://omniscribe-184475424927.europe-west4.run.app";

  // Alias getters for media & takt services
  static String get taktBackendUrl => backendUrl;
  static String get mediaBackendUrl => backendUrl;
}

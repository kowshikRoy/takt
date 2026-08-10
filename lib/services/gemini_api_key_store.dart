import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's own Gemini API key, used to transcribe videos client-side
/// (with the user's own quota) when the backend has no official subtitles.
class GeminiApiKeyStore {
  GeminiApiKeyStore._();

  static const _key = 'gemini_api_key';
  static const _storage = FlutterSecureStorage();

  static Future<String?> getKey() async {
    final value = await _storage.read(key: _key);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static Future<void> setKey(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: trimmed);
    }
  }
}

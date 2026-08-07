import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyGroqApi = 'groq_api_key';

  static Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _keyGroqApi, value: apiKey);
  }

  static Future<String?> getApiKey() async {
    return await _storage.read(key: _keyGroqApi);
  }
}

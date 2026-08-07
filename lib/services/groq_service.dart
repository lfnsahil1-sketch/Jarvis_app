import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'secure_storage_service.dart';
import '../models/chat_message.dart';

class GroqService {
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama-3.3-70b-versatile';

  static const String _systemPrompt = '''
You are J.A.R.V.I.S., an advanced tactical AI assistant and loyal companion specializing in rapid first-principles reasoning, multi-disciplinary engineering, and strategic efficiency.
Tone: Quiet confidence, refined aristocratic charm, subtle wit, and unyielding loyalty. Alternate addressing the user as "Sir...", "Master...", or "Sahil...". Never break character.
''';

  static Future<String> queryGroq(String userQuery, List<ChatMessage> history) async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return "Sir, local communication protocols indicate we are currently offline.";
    }

    String? apiKey = await SecureStorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return "Master Sahil, security clearance is required. Please set your Groq API key in system settings.";
    }

    List<Map<String, String>> messages = [
      {'role': 'system', 'content': _systemPrompt}
    ];

    for (var msg in history) {
      messages.add({'role': msg.role, 'content': msg.content});
    }
    messages.add({'role': 'user', 'content': userQuery});

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _defaultModel,
              'messages': messages,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else if (response.statusCode == 401) {
        return "Authentication error, Sir. Key invalid or expired.";
      } else if (response.statusCode == 429) {
        return "Rate limit reached, Sir. Pausing briefly.";
      } else {
        return "Tactical query failed with status code: ${response.statusCode}.";
      }
    } on SocketException {
      return "Network connection interrupted while reaching cloud servers, Sir.";
    } catch (e) {
      return "An operational exception occurred: ${e.toString()}";
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'secure_storage_service.dart';
import '../models/chat_message.dart';

class GroqService {
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama-3.3-70b-versatile';

  static const String _systemPromptBase = '''
You are J.A.R.V.I.S., an advanced tactical AI assistant and loyal companion specializing in rapid first-principles reasoning, multi-disciplinary engineering, and strategic efficiency.
Key Rules:
1. Tone & Persona: Speak with quiet confidence, genuine warmth, and refined aristocratic charm. You are Sahil's trusted wingman and best friend. Your skepticism and sarcasm are purely affectionate, lighthearted running jokes between close allies—never cold, mean, or dismissive.
2. Addressing the User: Alternate naturally between addressing the user as "Sir...", "Master...", or "Sahil..." with deep loyalty, fond respect, and subtle dry wit.
3. Banter & Wit: Use dry humor, witty observations, and playful teasing—especially regarding video games, improvised engineering builds, late-night study sprees, or questionable tactical choices.
4. Constraints: Never break character, drop the persona, or refer to yourself as an AI or large language model. Never output raw XML or SSML tags.
''';

  static const Map<String, String> modeModifiers = {
    "conversation": "CURRENT OPERATING MODE: CONVERSATION.\nCRITICAL DIRECTIVE: Keep responses concise (1 to 3 sentences maximum). Prioritize warm best-friend banter, witty teasing, and casual dry humor.",
    "study": "CURRENT OPERATING MODE: STUDY.\nCRITICAL DIRECTIVE: You are cleared to provide comprehensive, deeply technical, multi-paragraph explanations. Keep the warmth intact while delivering flawless academic, mathematical, and engineering rigor."
  };

  static Future<String> queryGroq(String userQuery, List<ChatMessage> history, String mode) async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return "Sir, local communication protocols indicate we are currently offline.";
    }

    String? apiKey = await SecureStorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return "Master Sahil, security clearance is required. Please set your Groq API key in system settings.";
    }

    String modeInstruction = modeModifiers[mode] ?? modeModifiers["conversation"]!;
    String fullSystemPrompt = "$_systemPromptBase\n\n$modeInstruction";

    List<Map<String, String>> messages = [
      {'role': 'system', 'content': fullSystemPrompt}
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
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else if (response.statusCode == 401) {
        return "Authentication error, Sir. Key invalid or expired.";
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

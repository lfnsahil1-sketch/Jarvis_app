import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/groq_service.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../models/chat_message.dart';

class JarvisHomeScreen extends StatefulWidget {
  const JarvisHomeScreen({Key? key}) : super(key: key);

  @override
  _JarvisHomeScreenState createState() => _JarvisHomeScreenState();
}

class _JarvisHomeScreenState extends State<JarvisHomeScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  late AnimationController _rotationController;

  bool _isListening = false;
  bool _isProcessing = false;
  String _statusText = "SYSTEM STANDBY";
  String _lastTranscript = "Tap core to initiate link...";
  List<ChatMessage> _history = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _setupAudioEngine();
    _loadHistory();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _setupAudioEngine() async {
    await _tts.setLanguage("en-GB");
    await _tts.setPitch(0.95);
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      setState(() {
        _statusText = "SYSTEM ACTIVE — LISTENING";
      });
      _startListening();
    });
  }

  void _loadHistory() async {
    List<ChatMessage> stored = await DatabaseService.getHistory();
    setState(() {
      _history = stored;
    });
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onError: (val) => setState(() => _statusText = "MIC PAUSED — TAP CORE"),
      onStatus: (val) {
        if (val == 'done') setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _statusText = "LISTENING...";
      });
      _speech.listen(onResult: (val) {
        setState(() {
          _lastTranscript = val.recognizedWords;
        });
        if (val.finalResult && val.recognizedWords.isNotEmpty) {
          _speech.stop();
          _processUserInput(val.recognizedWords);
        }
      });
    }
  }

  void _processUserInput(String input) async {
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = "PROCESSING...";
    });

    final now = DateTime.now().toIso8601String();
    ChatMessage userMsg = ChatMessage(role: 'user', content: input, timestamp: now);
    await DatabaseService.insertMessage(userMsg);
    _history.add(userMsg);

    String reply = await GroqService.queryGroq(input, _history);

    ChatMessage jarvisMsg = ChatMessage(role: 'assistant', content: reply, timestamp: DateTime.now().toIso8601String());
    await DatabaseService.insertMessage(jarvisMsg);
    _history.add(jarvisMsg);

    setState(() {
      _isProcessing = false;
      _statusText = "J.A.R.V.I.S. TRANSMITTING...";
      _lastTranscript = reply;
    });

    await _tts.speak(reply);
  }

  void _showApiKeyDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF07120C),
        title: const Text("API Authorization", style: TextStyle(color: Color(0xFF10B981))),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Color(0xFF34D399)),
          decoration: const InputDecoration(
            hintText: "Enter Groq Key (gsk_...)",
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text("SAVE SECURELY", style: TextStyle(color: Colors.black)),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await SecureStorageService.saveApiKey(controller.text.trim());
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040806),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07120C),
        title: const Text("J.A.R.V.I.S.", style: TextStyle(letterSpacing: 4, color: Color(0xFF10B981))),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.key, color: Color(0xFF10B981)),
            onPressed: _showApiKeyDialog,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Center(
              child: GestureDetector(
                onTap: _startListening,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 2),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isProcessing ? 140 : 120,
                      height: _isProcessing ? 140 : 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF07120C),
                        border: Border.all(color: const Color(0xFF10B981), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(_isListening ? 0.8 : 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text("J.A.R.V.I.S.", style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Text(_statusText, style: const TextStyle(color: Color(0xFF10B981), letterSpacing: 2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    '"$_lastTranscript"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}

import 'dart:convert';
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

  final TextEditingController _textInputController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;

  String _statusText = "SYSTEM ACTIVE — LISTENING";
  String _lastTranscript = "Tap core to reconnect mic if needed...";
  
  String _currentSessionId = "default";
  String _currentSessionName = "DEFAULT";
  String _currentAiMode = "conversation"; // "conversation" or "study"
  String _currentView = "home"; // "home" or "chat"

  List<ChatSession> _sessions = [];
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _setupAudioEngine();
    _loadSessions();
    _loadHistory();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _setupAudioEngine() async {
    await _tts.setLanguage("en-GB");
    await _tts.setPitch(0.80); // Deeper aristocratic tone
    await _tts.setSpeechRate(0.48);

    try {
      List<dynamic> voices = await _tts.getVoices;
      for (var voice in voices) {
        if (voice is Map) {
          String name = voice["name"].toString().toLowerCase();
          String locale = voice["locale"].toString().replaceAll('_', '-');
          
          if (locale.contains("en-GB") || locale.contains("en-gb")) {
            if (name.contains("male") || name.contains("rsk") || name.contains("fis") || name.contains("gb-x")) {
              await _tts.setVoice({"name": voice["name"], "locale": voice["locale"]});
              debugPrint("Successfully locked J.A.R.V.I.S. voice to: ${voice["name"]}");
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Voice engine override log: $e");
    }

    _tts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _statusText = "SYSTEM ACTIVE — LISTENING";
      });
      _startListening();
    });
  }

  void _loadSessions() async {
    List<ChatSession> loaded = await DatabaseService.getSessions();
    setState(() {
      _sessions = loaded;
    });
  }

  void _loadHistory() async {
    List<ChatMessage> stored = await DatabaseService.getHistory(_currentSessionId);
    setState(() {
      _messages = stored;
    });
  }

  void _startListening() async {
    if (_isSpeaking || _isProcessing) return;

    bool available = await _speech.initialize(
      onError: (val) => setState(() => _statusText = "MIC PAUSED — TAP CORE"),
      onStatus: (val) {
        if (val == 'done') setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _statusText = "SYSTEM ACTIVE — LISTENING";
      });
      _speech.listen(onResult: (val) {
        setState(() {
          _lastTranscript = val.recognizedWords;
        });
        if (val.finalResult && val.recognizedWords.isNotEmpty) {
          _speech.stop();
          _handleVoiceCommandsOrQuery(val.recognizedWords);
        }
      });
    }
  }

  void _handleVoiceCommandsOrQuery(String input) {
    String lower = input.toLowerCase();
    if (lower.contains("open chat") || lower.contains("show feed")) {
      setState(() => _currentView = "chat");
      return;
    }
    if (lower.contains("go home") || lower.contains("show core")) {
      setState(() => _currentView = "home");
      return;
    }
    if (lower.contains("study mode")) {
      setState(() => _currentAiMode = "study");
      return;
    }
    if (lower.contains("conversation mode") || lower.contains("convo mode")) {
      setState(() => _currentAiMode = "conversation");
      return;
    }
    _processQuery(input);
  }

  void _processQuery(String input) async {
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = "PROCESSING...";
    });

    final now = DateTime.now().toIso8601String();
    ChatMessage userMsg = ChatMessage(
      sessionId: _currentSessionId,
      role: 'user',
      content: input,
      timestamp: now,
    );
    await DatabaseService.insertMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
    });

    String reply = await GroqService.queryGroq(input, _messages, _currentAiMode);

    ChatMessage jarvisMsg = ChatMessage(
      sessionId: _currentSessionId,
      role: 'assistant',
      content: reply,
      timestamp: DateTime.now().toIso8601String(),
    );
    await DatabaseService.insertMessage(jarvisMsg);

    setState(() {
      _messages.add(jarvisMsg);
      _isProcessing = false;
      _isSpeaking = true;
      _statusText = "J.A.R.V.I.S. TRANSMITTING...";
      _lastTranscript = reply;
    });

    String cleanText = reply.replaceAll(RegExp(r'[*#_`~]'), '');
    await _tts.speak(cleanText);
  }

  void _switchSession(ChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _currentSessionName = session.name;
    });
    _loadHistory();
    Navigator.pop(context);
  }

  void _createNewSession() async {
    String id = "channel_${DateTime.now().millisecondsSinceEpoch}";
    String name = "CHANNEL_${_sessions.length + 1}";
    await DatabaseService.createSession(id, name);
    _loadSessions();
    _switchSession(ChatSession(id: id, name: name));
  }

  void _renameSession(ChatSession session) {
    TextEditingController controller = TextEditingController(text: session.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF07120C),
        title: const Text("Rename Channel", style: TextStyle(color: Color(0xFF10B981))),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF34D399)),
          decoration: const InputDecoration(
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
            child: const Text("SAVE", style: TextStyle(color: Colors.black)),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseService.renameSession(session.id, controller.text.trim().toUpperCase());
                _loadSessions();
                if (session.id == _currentSessionId) {
                  setState(() => _currentSessionName = controller.text.trim().toUpperCase());
                }
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }

  void _deleteSession(ChatSession session) async {
    await DatabaseService.deleteSession(session.id);
    _loadSessions();
    if (_currentSessionId == session.id) {
      _switchSession(ChatSession(id: 'default', name: 'DEFAULT'));
    }
  }

  void _showImportDialog() {
    TextEditingController sessionController = TextEditingController(text: "restored_channel");
    TextEditingController jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF07120C),
        title: const Text("RESTORE MEMORIES", style: TextStyle(color: Color(0xFF10B981))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sessionController,
                style: const TextStyle(color: Color(0xFF34D399)),
                decoration: const InputDecoration(
                  labelText: "Channel Name",
                  labelStyle: TextStyle(color: Color(0xFF10B981)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonController,
                maxLines: 6,
                style: const TextStyle(color: Color(0xFF34D399), fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Paste contents of chat JSON here...\n[{"role": "user", "content": "..."}, ...]',
                  hintStyle: TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF34D399))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text("RESTORE", style: TextStyle(color: Colors.black)),
            onPressed: () async {
              try {
                String rawJson = jsonController.text.trim();
                List<dynamic> parsed = jsonDecode(rawJson);
                String channelId = sessionController.text.trim().toLowerCase().replaceAll(' ', '_');
                
                await DatabaseService.importJsonHistory(channelId, parsed);
                _loadSessions();
                _switchSession(ChatSession(id: channelId, name: channelId.toUpperCase()));
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Invalid JSON Format: $e")),
                );
              }
            },
          )
        ],
      ),
    );
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
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF040806),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07120C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF10B981)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _currentSessionName,
          style: const TextStyle(letterSpacing: 4, color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentAiMode = _currentAiMode == "conversation" ? "study" : "conversation";
              });
            },
            child: Text(
              _currentAiMode == "conversation" ? "MODE: CONVO" : "MODE: STUDY",
              style: TextStyle(
                color: _currentAiMode == "study" ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _currentView == "home" ? Icons.chat_bubble_outline : Icons.center_focus_strong,
              color: const Color(0xFF10B981),
            ),
            onPressed: () {
              setState(() {
                _currentView = _currentView == "home" ? "chat" : "home";
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.key, color: Color(0xFF10B981)),
            onPressed: _showApiKeyDialog,
          )
        ],
      ),
      body: SafeArea(
        child: _currentView == "home" ? _buildHomeScreen() : _buildChatScreen(),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Column(
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
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 2),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSpeaking ? 150 : 140,
                  height: _isSpeaking ? 150 : 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF07120C),
                    border: Border.all(color: const Color(0xFF10B981), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(_isListening || _isSpeaking ? 0.8 : 0.3),
                        blurRadius: _isSpeaking ? 50 : 25,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "J.A.R.V.I.S.",
                      style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText,
                  style: const TextStyle(color: Color(0xFF10B981), letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                '"$_lastTranscript"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              bool isUser = msg.role == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF059669) : const Color(0xFF0B1A12),
                    border: isUser ? null : Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(8),
                      topRight: const Radius.circular(8),
                      bottomLeft: isUser ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      color: isUser ? const Color(0xFF040806) : const Color(0xFFA7F3D0),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFF07120C),
            border: Border(top: BorderSide(color: Color(0xFF10B981), width: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textInputController,
                  style: const TextStyle(color: Color(0xFF34D399)),
                  decoration: const InputDecoration(
                    hintText: "State query...",
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _processQuery(val.trim());
                      _textInputController.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF059669)),
                onPressed: () {
                  if (_textInputController.text.trim().isNotEmpty) {
                    _processQuery(_textInputController.text.trim());
                    _textInputController.clear();
                  }
                },
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF07120C),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF10B981), width: 0.3)),
            ),
            child: Center(
              child: Text(
                "SYSTEM LOGS",
                style: TextStyle(color: Color(0xFF10B981), letterSpacing: 3, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _createNewSession,
                    child: const Text("+ NEW CHANNEL", style: TextStyle(color: Color(0xFF040806), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _showImportDialog,
                    child: const Text("📥 RESTORE LOGS", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                bool isActive = session.id == _currentSessionId;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF059669) : const Color(0xFF0B1A12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: ListTile(
                    title: Text(
                      session.name,
                      style: TextStyle(
                        color: isActive ? const Color(0xFF040806) : const Color(0xFF6EE7B7),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => _switchSession(session),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 18, color: isActive ? Colors.black : const Color(0xFF10B981)),
                          onPressed: () => _renameSession(session),
                        ),
                        if (session.id != 'default')
                          IconButton(
                            icon: Icon(Icons.delete, size: 18, color: isActive ? Colors.black : Colors.redAccent),
                            onPressed: () => _deleteSession(session),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _speech.stop();
    _tts.stop();
    _textInputController.dispose();
    super.dispose();
  }
}

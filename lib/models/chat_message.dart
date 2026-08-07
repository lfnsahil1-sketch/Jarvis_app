class ChatMessage {
  final int? id;
  final String sessionId;
  final String role;
  final String content;
  final String timestamp;

  ChatMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'],
        sessionId: map['session_id'] ?? 'default',
        role: map['role'],
        content: map['content'],
        timestamp: map['timestamp'],
      );
}

class ChatSession {
  final String id;
  final String name;

  ChatSession({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
        id: map['id'],
        name: map['name'],
      );
}

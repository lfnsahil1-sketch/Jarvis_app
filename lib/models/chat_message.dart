class ChatMessage {
  final int? id;
  final String role;
  final String content;
  final String timestamp;

  ChatMessage({this.id, required this.role, required this.content, required this.timestamp});

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'],
        role: map['role'],
        content: map['content'],
        timestamp: map['timestamp'],
      );
}

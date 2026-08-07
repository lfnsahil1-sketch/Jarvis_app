import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'jarvis_memory.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.insert('sessions', {'id': 'default', 'name': 'DEFAULT'});
      },
    );
  }

  static Future<List<ChatSession>> getSessions() async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query('sessions');
    return maps.map((m) => ChatSession.fromMap(m)).toList();
  }

  static Future<List<ChatMessage>> getHistory(String sessionId) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  static Future<void> insertMessage(ChatMessage msg) async {
    final db = await database;
    await db.insert('messages', msg.toMap());
  }

  static Future<void> createSession(String id, String name) async {
    final db = await database;
    await db.insert(
      'sessions',
      {'id': id, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> renameSession(String id, String newName) async {
    final db = await database;
    await db.update('sessions', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
  }

  static Future<void> importJsonHistory(String sessionId, List<dynamic> jsonList) async {
    final db = await database;
    await createSession(sessionId, sessionId.toUpperCase());
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);

    for (var item in jsonList) {
      if (item is Map && item.containsKey('role') && item.containsKey('content')) {
        String role = item['role'];
        if (role == 'system') continue;

        await db.insert('messages', {
          'session_id': sessionId,
          'role': role,
          'content': item['content'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
  }
}

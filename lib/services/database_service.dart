import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'jarvis_memory.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            role TEXT,
            content TEXT,
            timestamp TEXT
          )
        ''');
        // Seed default channel
        await db.insert('sessions', {'id': 'default', 'name': 'DEFAULT'});
      },
    );
  }

  // --- Session Management ---
  static Future<List<ChatSession>> getSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions');
    if (maps.isEmpty) {
      await db.insert('sessions', {'id': 'default', 'name': 'DEFAULT'});
      return [ChatSession(id: 'default', name: 'DEFAULT')];
    }
    return List.generate(maps.length, (i) => ChatSession.fromMap(maps[i]));
  }

  static Future<void> createSession(String id, String name) async {
    final db = await database;
    await db.insert('sessions', {'id': id, 'name': name},
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  // --- Message Management ---
  static Future<void> insertMessage(ChatMessage msg) async {
    final db = await database;
    await db.insert('messages', msg.toMap());
  }

  static Future<List<ChatMessage>> getHistory(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'talk_ai.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE api_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'openai',
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT 'gpt-4o-mini',
        max_tokens INTEGER NOT NULL DEFAULT 4096,
        temperature REAL NOT NULL DEFAULT 0.8,
        stream_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT,
        description TEXT NOT NULL DEFAULT '',
        api_config_id TEXT,
        system_prompt TEXT NOT NULL DEFAULT '',
        character_card_json TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        pinned INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_message TEXT,
        last_message_at TEXT,
        proactive_enabled INTEGER NOT NULL DEFAULT 1,
        last_proactive_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        contact_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'text',
        is_streaming INTEGER NOT NULL DEFAULT 0,
        token_count INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        created_at TEXT,
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_messages_contact_id ON messages(contact_id)');
    await db.execute('CREATE INDEX idx_messages_created_at ON messages(created_at)');

    await db.execute('''
      CREATE TABLE moments (
        id TEXT PRIMARY KEY,
        contact_id TEXT NOT NULL,
        content TEXT NOT NULL,
        image_url TEXT,
        likes TEXT NOT NULL DEFAULT '[]',
        comments TEXT NOT NULL DEFAULT '[]',
        created_at TEXT,
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_moments_contact_id ON moments(contact_id)');
    await db.execute('CREATE INDEX idx_moments_created_at ON moments(created_at)');

    await db.execute('''
      CREATE TABLE chat_presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        segments TEXT NOT NULL DEFAULT '[]',
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cart_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        shop TEXT
      )
    ''');
  }

  Future<void> _onOpen(Database db) async {
    // 重置应用崩溃/强退后遗留的 is_streaming=1 消息
    await db.update('messages', {'is_streaming': 0},
        where: 'is_streaming = 1');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE contacts ADD COLUMN proactive_enabled INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE contacts ADD COLUMN last_proactive_at TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN metadata TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS moments (
          id TEXT PRIMARY KEY,
          contact_id TEXT NOT NULL,
          content TEXT NOT NULL,
          image_url TEXT,
          likes TEXT NOT NULL DEFAULT '[]',
          comments TEXT NOT NULL DEFAULT '[]',
          created_at TEXT,
          FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_moments_contact_id ON moments(contact_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_moments_created_at ON moments(created_at)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_presets (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          segments TEXT NOT NULL DEFAULT '[]',
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cart_items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          price REAL NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 1,
          shop TEXT
        )
      ''');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

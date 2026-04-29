import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';

/// Database Service for local SQLite operations
/// 
/// Manages:
/// - Users, Words, Categories, Progress tables
/// - Word learning state (learned, errors, repeat)
/// - Spaced repetition scheduling
class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;

  DatabaseService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);

    return await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableUsers} (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        avatar TEXT,
        coins INTEGER DEFAULT 0,
        is_premium INTEGER DEFAULT 0,
        premium_expires_at TEXT,
        base_language TEXT DEFAULT 'ru',
        learn_language TEXT DEFAULT 'en',
        access_token TEXT,
        refresh_token TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableCategories} (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        name_ru TEXT,
        name_en TEXT,
        icon TEXT,
        color TEXT,
        order_index INTEGER DEFAULT 0,
        is_premium INTEGER DEFAULT 0,
        word_count INTEGER DEFAULT 0
      )
    ''');

    // Sub-Categories table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableSubCategories} (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        name_ru TEXT,
        name_en TEXT,
        order_index INTEGER DEFAULT 0,
        word_count INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES ${DbConstants.tableCategories}(id)
      )
    ''');

    // Words table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableWords} (
        id INTEGER PRIMARY KEY,
        category_id INTEGER,
        sub_category_id INTEGER,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        transcription TEXT,
        example TEXT,
        example_translation TEXT,
        audio_url TEXT,
        image_url TEXT,
        difficulty INTEGER DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES ${DbConstants.tableCategories}(id),
        FOREIGN KEY (sub_category_id) REFERENCES ${DbConstants.tableSubCategories}(id)
      )
    ''');

    // Learned Words table (user progress)
    await db.execute('''
      CREATE TABLE ${DbConstants.tableLearnedWords} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        level INTEGER DEFAULT 0,
        repeat_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        error_count INTEGER DEFAULT 0,
        last_seen_at TEXT,
        next_repeat_at TEXT,
        is_learned INTEGER DEFAULT 0,
        created_at TEXT,
        UNIQUE(user_id, word_id),
        FOREIGN KEY (word_id) REFERENCES ${DbConstants.tableWords}(id)
      )
    ''');

    // Error Words table (words with mistakes)
    await db.execute('''
      CREATE TABLE ${DbConstants.tableErrorWords} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        error_count INTEGER DEFAULT 1,
        last_error_at TEXT,
        UNIQUE(user_id, word_id),
        FOREIGN KEY (word_id) REFERENCES ${DbConstants.tableWords}(id)
      )
    ''');

    // Progress table (daily/weekly stats)
    await db.execute('''
      CREATE TABLE ${DbConstants.tableProgress} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        words_learned INTEGER DEFAULT 0,
        words_repeated INTEGER DEFAULT 0,
        games_played INTEGER DEFAULT 0,
        correct_answers INTEGER DEFAULT 0,
        total_answers INTEGER DEFAULT 0,
        time_spent_seconds INTEGER DEFAULT 0,
        coins_earned INTEGER DEFAULT 0,
        UNIQUE(user_id, date)
      )
    ''');

    // Achievements table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableAchievements} (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        achievement_id TEXT NOT NULL,
        unlocked_at TEXT,
        claimed INTEGER DEFAULT 0,
        UNIQUE(user_id, achievement_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_words_category ON ${DbConstants.tableWords}(category_id)'
    );
    await db.execute(
      'CREATE INDEX idx_learned_user ON ${DbConstants.tableLearnedWords}(user_id)'
    );
    await db.execute(
      'CREATE INDEX idx_learned_next_repeat ON ${DbConstants.tableLearnedWords}(next_repeat_at)'
    );
    await db.execute(
      'CREATE INDEX idx_progress_user_date ON ${DbConstants.tableProgress}(user_id, date)'
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE users ADD COLUMN new_field TEXT');
    // }
  }

  // ==================== Generic CRUD Operations ====================

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete database file (for testing/logout)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

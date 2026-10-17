import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// الأصوات المضمّنة في التطبيق (ملفات داخل assets، وليست مسارات مؤقتة).
const List<(String, String, String)> kBuiltInSounds = [
  ('bell_classic', 'جرس مدرسي كلاسيكي', 'assets/sounds/bell_classic.wav'),
  ('bell_electric', 'جرس إلكتروني', 'assets/sounds/bell_electric.wav'),
  ('bell_chime', 'نغمة دق ودق', 'assets/sounds/bell_chime.wav'),
  ('bell_soft', 'نغمة هادئة', 'assets/sounds/bell_soft.wav'),
];

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int version = 1;
  static const String fileName = 'smart_school_bell.db';

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE schools(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        address TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE buildings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_id INTEGER NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        volume REAL NOT NULL DEFAULT 1.0 CHECK(volume >= 0 AND volume <= 1),
        default_sound TEXT
      )''');
    await db.execute('''
      CREATE TABLE schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
        day_of_week INTEGER NOT NULL CHECK(day_of_week BETWEEN 1 AND 7),
        is_working INTEGER NOT NULL DEFAULT 1,
        UNIQUE(building_id, day_of_week)
      )''');
    await db.execute('''
      CREATE TABLE bell_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id INTEGER NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
        event_type TEXT NOT NULL,
        event_time TEXT NOT NULL,
        label TEXT,
        subject TEXT,
        sound_id TEXT,
        duration_sec INTEGER NOT NULL DEFAULT 5 CHECK(duration_sec BETWEEN 1 AND 300),
        is_enabled INTEGER NOT NULL DEFAULT 1
      )''');
    // kind: official | school | exceptional | override (يوم دوام استثنائي يلغي التعطيل)
    await db.execute('''
      CREATE TABLE holidays(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_id INTEGER NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
        building_id INTEGER REFERENCES buildings(id) ON DELETE CASCADE,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        kind TEXT NOT NULL DEFAULT 'official',
        notes TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE sound_profiles(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        asset_path TEXT NOT NULL
      )''');
    // log_kind: bell | schedule | change | error
    await db.execute('''
      CREATE TABLE execution_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts TEXT NOT NULL,
        log_kind TEXT NOT NULL DEFAULT 'bell',
        school_name TEXT,
        building_name TEXT,
        building_id INTEGER,
        event_id INTEGER,
        event_label TEXT,
        scheduled_date TEXT,
        mode TEXT,
        result TEXT,
        message TEXT,
        is_hidden INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE app_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await db.execute('CREATE INDEX idx_events_schedule ON bell_events(schedule_id)');
    await db.execute('CREATE INDEX idx_holidays_range ON holidays(school_id, start_date, end_date)');
    await db.execute('CREATE INDEX idx_logs_event ON execution_logs(building_id, event_id, scheduled_date)');
    await db.execute('CREATE INDEX idx_logs_ts ON execution_logs(ts)');

    for (final s in kBuiltInSounds) {
      await db.insert('sound_profiles', {'id': s.$1, 'name': s.$2, 'asset_path': s.$3});
    }
  }

  /// آلية الترقية: أضف خطوة لكل إصدار جديد، وارفع [version].
  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    // مثال:
    // if (oldV < 2) { await db.execute('ALTER TABLE buildings ADD COLUMN note TEXT'); }
  }

  Future<void> close() => db.close();
}

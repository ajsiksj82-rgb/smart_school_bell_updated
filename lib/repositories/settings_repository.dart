import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart' show kBuiltInSounds;
import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../models/models.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  Future<String?> get(String key) async {
    final r = await _db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('app_settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<SoundProfile>> sounds() async =>
      (await _db.query('sound_profiles', orderBy: 'rowid')).map(SoundProfile.fromMap).toList();

  /// يضيف الأصوات المضمّنة الجديدة للتثبيتات القديمة (لا يغيّر الموجود).
  Future<void> ensureBuiltInSounds() async {
    for (final s in kBuiltInSounds) {
      await _db.insert('sound_profiles', {'id': s.$1, 'name': s.$2, 'asset_path': s.$3},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> addCustomSound(String id, String name, String filePath) => _db.insert(
      'sound_profiles', {'id': id, 'name': name, 'asset_path': filePath},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteSound(String id) => _db.delete('sound_profiles', where: 'id = ?', whereArgs: [id]);

  /// الأحداث التي يمكن تخصيص جرس لها، ومفتاح الإعداد لكل منها.
  static const Map<BellEventType, String> categoryKeys = {
    BellEventType.lessonStart: 'sound_lesson_start',
    BellEventType.lessonEnd: 'sound_lesson_end',
    BellEventType.assemblyStart: 'sound_assembly_start',
  };

  Future<Map<BellEventType, String?>> categorySounds() async => {
        for (final e in categoryKeys.entries) e.key: await get(e.value),
      };
}

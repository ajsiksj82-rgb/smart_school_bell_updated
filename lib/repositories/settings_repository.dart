import 'package:sqflite/sqflite.dart';

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
}

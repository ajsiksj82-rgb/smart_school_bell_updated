import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'log_repository.dart';

class SchoolRepository {
  SchoolRepository(this._db, this._log, this._onChanged);
  final Database _db;
  final LogRepository _log;
  final void Function() _onChanged;

  Future<List<School>> schools() async =>
      (await _db.query('schools', orderBy: 'name')).map(School.fromMap).toList();

  Future<int> addSchool(School s) async {
    final map = s.toMap()..remove('id');
    final id = await _db.insert('schools', map);
    await _log.change('إضافة مدرسة: ${s.name}');
    _onChanged();
    return id;
  }

  Future<void> updateSchool(School s) async {
    await _db.update('schools', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    await _log.change('تعديل مدرسة: ${s.name}${s.isActive ? '' : ' (معطّلة)'}');
    _onChanged();
  }

  /// ما سيُحذف مع المدرسة (لعرضه في نافذة التأكيد).
  Future<Map<String, int>> schoolImpact(int id) async {
    final b = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM buildings WHERE school_id = ?', [id])) ?? 0;
    final e = Sqflite.firstIntValue(await _db.rawQuery('''
          SELECT COUNT(*) FROM bell_events ev
          JOIN schedules s ON s.id = ev.schedule_id
          JOIN buildings b ON b.id = s.building_id
          WHERE b.school_id = ?''', [id])) ?? 0;
    final h = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM holidays WHERE school_id = ?', [id])) ?? 0;
    return {'buildings': b, 'events': e, 'holidays': h};
  }

  Future<Map<String, int>> buildingImpact(int id) async {
    final e = Sqflite.firstIntValue(await _db.rawQuery('''
          SELECT COUNT(*) FROM bell_events ev
          JOIN schedules s ON s.id = ev.schedule_id
          WHERE s.building_id = ?''', [id])) ?? 0;
    final h = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM holidays WHERE building_id = ?', [id])) ?? 0;
    return {'events': e, 'holidays': h};
  }

  Future<void> deleteSchool(int id, String name) async {
    await _db.delete('schools', where: 'id = ?', whereArgs: [id]);
    await _log.change('حذف مدرسة: $name');
    _onChanged();
  }

  Future<List<Building>> buildings(int schoolId) async =>
      (await _db.query('buildings', where: 'school_id = ?', whereArgs: [schoolId], orderBy: 'name'))
          .map(Building.fromMap)
          .toList();

  Future<Building?> building(int id) async {
    final r = await _db.query('buildings', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Building.fromMap(r.first);
  }

  Future<List<BuildingRef>> allBuildingRefs() async {
    final rows = await _db.rawQuery('''
      SELECT b.*, s.name AS school_name, s.is_active AS school_active
      FROM buildings b JOIN schools s ON s.id = b.school_id
      ORDER BY s.name, b.name''');
    return rows
        .map((r) => BuildingRef(Building.fromMap(r), r['school_name'] as String,
            (r['school_active'] as int? ?? 1) == 1))
        .toList();
  }

  /// يضيف المبنى مع جدول مستقل لكل يوم (الدوام من السبت إلى الأربعاء، والخميس والجمعة عطلة افتراضيًا).
  Future<int> addBuilding(Building b) async {
    late int id;
    await _db.transaction((txn) async {
      final map = b.toMap()..remove('id');
      id = await txn.insert('buildings', map);
      for (var wd = 1; wd <= 7; wd++) {
        await txn.insert('schedules', {
          'building_id': id,
          'day_of_week': wd,
          'is_working': (wd == DateTime.thursday || wd == DateTime.friday) ? 0 : 1,
        });
      }
    });
    await _log.change('إضافة مبنى: ${b.name}');
    _onChanged();
    return id;
  }

  Future<void> updateBuilding(Building b) async {
    await _db.update('buildings', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
    await _log.change('تعديل مبنى: ${b.name}');
    _onChanged();
  }

  Future<void> deleteBuilding(int id, String name) async {
    await _db.delete('buildings', where: 'id = ?', whereArgs: [id]);
    await _log.change('حذف مبنى: $name');
    _onChanged();
  }
}

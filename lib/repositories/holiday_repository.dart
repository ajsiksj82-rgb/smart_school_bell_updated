import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/time_utils.dart';
import 'log_repository.dart';

class HolidayRepository {
  HolidayRepository(this._db, this._log, this._onChanged);
  final Database _db;
  final LogRepository _log;
  final void Function() _onChanged;

  Future<List<Holiday>> forSchool(int schoolId) async => (await _db.query('holidays',
          where: 'school_id = ?', whereArgs: [schoolId], orderBy: 'start_date DESC, id DESC'))
      .map(Holiday.fromMap)
      .toList();

  /// يرجع null عند النجاح أو رسالة خطأ.
  Future<String?> save(Holiday h) async {
    if (h.title.trim().isEmpty) return 'اكتب اسم الإجازة';
    if (h.end.isBefore(h.start)) return 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية أو مساويًا له';
    if (!holidayKindLabels.containsKey(h.kind)) return 'نوع إجازة غير معروف';
    try {
      if (h.id == null) {
        final m = h.toMap()..remove('id');
        await _db.insert('holidays', m);
      } else {
        await _db.update('holidays', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
      }
    } on DatabaseException catch (e) {
      return 'تعذر حفظ الإجازة: $e';
    }
    await _log.change('${h.id == null ? 'إضافة' : 'تعديل'} ${holidayKindLabels[h.kind]}: ${h.title} (${ymd(h.start)} → ${ymd(h.end)})');
    _onChanged();
    return null;
  }

  Future<void> delete(Holiday h) async {
    await _db.delete('holidays', where: 'id = ?', whereArgs: [h.id]);
    await _log.change('حذف ${holidayKindLabels[h.kind]}: ${h.title}');
    _onChanged();
  }

  Future<void> setActive(Holiday h, bool active) async {
    await _db.update('holidays', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [h.id]);
    _onChanged();
  }
}

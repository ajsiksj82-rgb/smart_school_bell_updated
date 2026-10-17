import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/time_utils.dart';

class LogRepository {
  LogRepository(this._db);
  final Database _db;

  Future<void> add({
    required String kind,
    String? message,
    String? result,
    String? schoolName,
    String? buildingName,
    int? buildingId,
    int? eventId,
    String? eventLabel,
    String? scheduledDate,
    String? mode,
    DateTime? at,
    bool hidden = false,
  }) async {
    try {
      await _db.insert('execution_logs', {
        'ts': (at ?? DateTime.now()).toIso8601String(),
        'log_kind': kind,
        'school_name': schoolName,
        'building_name': buildingName,
        'building_id': buildingId,
        'event_id': eventId,
        'event_label': eventLabel,
        'scheduled_date': scheduledDate,
        'mode': mode,
        'result': result,
        'message': message,
        'is_hidden': hidden ? 1 : 0,
      });
    } catch (_) {
      // السجل لا يجب أن يوقف التطبيق.
    }
  }

  Future<void> change(String message) => add(kind: 'change', message: message, result: 'info');
  Future<void> schedule(String message, {String result = 'info'}) =>
      add(kind: 'schedule', message: message, result: result);
  Future<void> error(String message) => add(kind: 'error', message: message, result: 'error');

  /// [day] لتصفية يوم محدد، [kind] لنوع الحدث (bell/schedule/change/error).
  Future<List<LogEntry>> query({DateTime? day, String? kind, int limit = 300}) async {
    final where = <String>['is_hidden = 0'];
    final args = <Object?>[];
    if (day != null) {
      final from = DateTime(day.year, day.month, day.day);
      final to = from.add(const Duration(days: 1));
      where.add('ts >= ? AND ts < ?');
      args..add(from.toIso8601String())..add(to.toIso8601String());
    }
    if (kind != null) {
      where.add('log_kind = ?');
      args.add(kind);
    }
    final rows = await _db.query('execution_logs',
        where: where.join(' AND '), whereArgs: args, orderBy: 'ts DESC, id DESC', limit: limit);
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('execution_logs');
  }

  /// يدخل سجلات الجرس القادمة من الكود الأصلي (Kotlin). يرجع عدد السجلات المُدخلة.
  Future<int> importNative(List<dynamic> entries) async {
    var n = 0;
    for (final raw in entries) {
      if (raw is! Map) continue;
      final ts = raw['ts'];
      final at = ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime.now();
      final ids = <int>[];
      final idsRaw = raw['eventIds'];
      if (idsRaw is List) {
        for (final v in idsRaw) {
          if (v is int) ids.add(v);
        }
      }
      final primary = raw['eventId'] is int && (raw['eventId'] as int) > 0 ? raw['eventId'] as int : null;
      if (ids.isEmpty && primary != null) ids.add(primary);
      final base = (
        building: raw['buildingId'] is int && (raw['buildingId'] as int) > 0 ? raw['buildingId'] as int : null,
        school: raw['schoolName'] as String?,
        bname: raw['buildingName'] as String?,
        label: raw['label'] as String?,
        date: (raw['date'] as String?)?.isEmpty ?? true ? ymd(at) : raw['date'] as String?,
        mode: raw['mode'] as String?,
        result: raw['result'] as String?,
        msg: (raw['error'] as String?)?.isEmpty ?? true ? null : raw['error'] as String?,
      );
      if (ids.isEmpty) {
        await add(
            kind: 'bell', at: at, result: base.result, message: base.msg, schoolName: base.school,
            buildingName: base.bname, buildingId: base.building, eventLabel: base.label,
            scheduledDate: base.date, mode: base.mode);
        n++;
        continue;
      }
      // الجرس الواحد قد يغطي أكثر من حدث (نفس الدقيقة): صف ظاهر + صفوف مخفية للتحقق.
      for (var i = 0; i < ids.length; i++) {
        await add(
            kind: 'bell', at: at, result: base.result, message: base.msg, schoolName: base.school,
            buildingName: base.bname, buildingId: base.building, eventId: ids[i],
            eventLabel: base.label, scheduledDate: base.date, mode: base.mode, hidden: i > 0);
      }
      n++;
    }
    return n;
  }
}

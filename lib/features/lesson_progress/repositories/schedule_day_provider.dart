import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../models/lesson_progress_models.dart';

class HolidayResolution {
  const HolidayResolution(this.holidayTitle, this.overrideTitle);
  final String? holidayTitle;
  final String? overrideTitle;
}

/// يحدد إن كان اليوم إجازة أو يوم دوام استثنائي (يلغي التعطيل) لمبنى محدد.
Future<HolidayResolution> resolveHoliday(
    DatabaseExecutor db, int buildingId, DateTime date) async {
  final d = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final rows = await db.rawQuery('''
    SELECT title, kind FROM holidays
    WHERE is_active = 1 AND start_date <= ? AND end_date >= ?
      AND (building_id = ?
           OR (building_id IS NULL AND school_id =
               (SELECT school_id FROM buildings WHERE id = ?)))
  ''', [d, d, buildingId, buildingId]);
  String? holiday;
  String? override;
  for (final r in rows) {
    if (r['kind'] == 'override') {
      override ??= r['title'] as String?;
    } else {
      holiday ??= r['title'] as String?;
    }
  }
  return HolidayResolution(holiday, override);
}

/// واجهة مصدر البيانات التي تعتمد عليها الميزة.
abstract class ScheduleDayProvider {
  /// فترات يوم محدد لمبنى محدد، مع معالجة الإجازات وأيام عدم الدوام.
  Future<DayScheduleResult> loadDay(int buildingId, DateTime date);

  /// هل سُجّل تنفيذ جرس هذا الحدث في هذا اليوم؟
  /// (بدء تشغيل الصوت فقط، وليس تأكيد سماعه عبر المكبرات.)
  Future<bool> wasBellExecuted(int buildingId, int eventId, DateTime date);

  /// يُصدر إشارة عند تعديل الجدول أو الإجازات.
  Stream<void> get changes;
}

/// محوّل SQLite.
///
/// افتراضات أسماء الأعمدة (عدّلها لتطابق مخططك الفعلي):
/// - buildings(id, school_id)
/// - holidays(title, kind, start_date, end_date 'yyyy-MM-dd', school_id,
///            building_id NULLABLE, is_active)  [kind='override' يلغي التعطيل]
/// - schedules(id, building_id, day_of_week 1=الاثنين..7=الأحد, is_working)
/// - bell_events(id, schedule_id, event_type = اسم BellEventType,
///               event_time 'HH:mm', label, subject, is_enabled)
/// - execution_logs(log_kind, building_id, event_id, scheduled_date, result)
///                  حيث result = 'success' يعني بدء تشغيل الصوت
class SqliteScheduleDayProvider implements ScheduleDayProvider {
  SqliteScheduleDayProvider(this._db, {this.beforeLogQuery});

  final Database _db;

  /// يُستدعى قبل الاستعلام عن سجل التنفيذ (مثلًا لسحب سجلات الجرس الأصلية).
  final Future<void> Function()? beforeLogQuery;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// استدعها من المستودعات بعد أي تعديل على الجداول أو الإجازات أو المباني.
  void notifyChanged() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<DayScheduleResult> loadDay(int buildingId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final ymd = _ymd(day);

    final res = await resolveHoliday(_db, buildingId, day);
    final overridden = res.overrideTitle != null;
    if (res.holidayTitle != null && !overridden) {
      return DayScheduleResult(
        date: day,
        status: DayStatus.holiday,
        holidayName: res.holidayTitle,
      );
    }

    final sched = await _db.query(
      'schedules',
      columns: ['id', 'is_working'],
      where: 'building_id = ? AND day_of_week = ?',
      whereArgs: [buildingId, day.weekday],
      limit: 1,
    );
    if (sched.isEmpty) {
      return DayScheduleResult(date: day, status: DayStatus.noSchedule);
    }
    if (!overridden && (sched.first['is_working'] as int? ?? 1) == 0) {
      return DayScheduleResult(date: day, status: DayStatus.nonWorkingDay);
    }

    final rows = await _db.query(
      'bell_events',
      where: 'schedule_id = ?',
      whereArgs: [sched.first['id']],
    );

    final events = <BellEventInput>[];
    for (final r in rows) {
      final type = BellEventType.values
          .where((t) => t.name == r['event_type'])
          .firstOrNull;
      final minute = _parseMinute(r['event_time'] as String?);
      if (type == null || minute == null) continue;
      events.add(BellEventInput(
        id: r['id'] as int,
        type: type,
        minuteOfDay: minute,
        label: r['label'] as String?,
        subject: r['subject'] as String?,
        enabled: (r['is_enabled'] as int? ?? 1) == 1,
      ));
    }

    return DayScheduleResult(
      date: day,
      status: DayStatus.working,
      segments: SegmentBuilder.build(day, events),
    );
  }

  @override
  Future<bool> wasBellExecuted(
      int buildingId, int eventId, DateTime date) async {
    if (beforeLogQuery != null) {
      try {
        await beforeLogQuery!();
      } catch (_) {}
    }
    final rows = await _db.query(
      'execution_logs',
      columns: ['1'],
      where:
          "log_kind = 'bell' AND building_id = ? AND event_id = ? AND scheduled_date = ? AND result = 'success'",
      whereArgs: [buildingId, eventId, _ymd(date)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static int? _parseMinute(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  void dispose() => _changes.close();
}

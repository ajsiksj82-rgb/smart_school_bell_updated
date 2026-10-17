import 'package:sqflite/sqflite.dart';

import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../features/lesson_progress/repositories/schedule_day_provider.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import 'log_repository.dart';
import 'slot_logic.dart';

class ScheduleRepository {
  ScheduleRepository(this._db, this._log, this._onChanged);
  final Database _db;
  final LogRepository _log;
  final void Function() _onChanged;

  Future<ScheduleDay> day(int buildingId, int weekday) async {
    var r = await _db.query('schedules',
        where: 'building_id = ? AND day_of_week = ?', whereArgs: [buildingId, weekday], limit: 1);
    if (r.isEmpty) {
      await _db.insert('schedules',
          {'building_id': buildingId, 'day_of_week': weekday, 'is_working': 1});
      r = await _db.query('schedules',
          where: 'building_id = ? AND day_of_week = ?', whereArgs: [buildingId, weekday], limit: 1);
    }
    return ScheduleDay.fromMap(r.first);
  }

  Future<void> setWorking(int scheduleId, bool working) async {
    await _db.update('schedules', {'is_working': working ? 1 : 0},
        where: 'id = ?', whereArgs: [scheduleId]);
    await _log.change('تغيير حالة يوم الدوام (${working ? 'دوام' : 'عطلة'})');
    _onChanged();
  }

  Future<List<BellEvent>> events(int scheduleId) async => (await _db.query('bell_events',
          where: 'schedule_id = ?', whereArgs: [scheduleId], orderBy: 'event_time, id'))
      .map(BellEvent.fromMap)
      .toList();

  /// يرجع null عند النجاح، أو رسالة خطأ عربية.
  Future<String?> saveEvent(BellEvent e) async {
    if (e.minute < 0 || e.minute > 1439) return 'وقت غير صالح';
    if (e.durationSec < 1 || e.durationSec > 300) return 'مدة الرنين يجب أن تكون بين 1 و300 ثانية';
    final dup = await _db.query('bell_events',
        where: 'schedule_id = ? AND event_type = ? AND event_time = ?' +
            (e.id != null ? ' AND id != ?' : ''),
        whereArgs: [e.scheduleId, e.type.name, hm(e.minute), if (e.id != null) e.id],
        limit: 1);
    if (dup.isNotEmpty) return 'يوجد حدث بالنوع والوقت نفسيهما في هذا اليوم';
    final problem = await _conflict(e);
    if (problem != null) return problem;
    try {
      if (e.id == null) {
        final map = e.toMap()..remove('id');
        await _db.insert('bell_events', map);
      } else {
        await _db.update('bell_events', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
      }
    } on DatabaseException catch (ex) {
      return 'تعذر حفظ الحدث: ${ex.toString()}';
    }
    await _log.change('${e.id == null ? 'إضافة' : 'تعديل'} حدث جرس: ${bellTypeLabel(e.type)} ${hm(e.minute)}');
    _onChanged();
    return null;
  }

  /// منع التعارض غير المقصود: بداية حصة وسط حصة أخرى، أو نهاية قبل البداية.
  Future<String?> _conflict(BellEvent e) async {
    final others = (await events(e.scheduleId)).where((x) => x.id != e.id).toList();
    final all = [...others, e]..sort((a, b) => a.minute.compareTo(b.minute));
    // تحقق من تسلسل منطقي: لا توجد نهاية حصة دون بداية حصة سابقة غير مغلقة.
    var lessonOpen = false;
    var breakOpen = false;
    for (final x in all) {
      switch (x.type) {
        case BellEventType.lessonStart:
          lessonOpen = true;
          breakOpen = false;
        case BellEventType.breakStart:
          breakOpen = true;
          lessonOpen = false;
        case BellEventType.lessonEnd:
          if (!lessonOpen && x.minute == e.minute && x.type == e.type) {
            return 'نهاية الحصة يجب أن تأتي بعد بداية حصة';
          }
          lessonOpen = false;
        case BellEventType.breakEnd:
          if (!breakOpen && x.minute == e.minute && x.type == e.type) {
            return 'نهاية الاستراحة يجب أن تأتي بعد بداية استراحة';
          }
          breakOpen = false;
        default:
          break;
      }
    }
    return null;
  }

  Future<void> deleteEvent(BellEvent e) async {
    await _db.delete('bell_events', where: 'id = ?', whereArgs: [e.id]);
    await _log.change('حذف حدث جرس: ${bellTypeLabel(e.type)} ${hm(e.minute)}');
    _onChanged();
  }

  Future<void> setEnabled(BellEvent e, bool enabled) async {
    await _db.update('bell_events', {'is_enabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [e.id]);
    _onChanged();
  }

  /// ينسخ أحداث يوم إلى أيام أخرى (يستبدل أحداثها الحالية).
  Future<void> copyDay(int fromScheduleId, List<int> toScheduleIds) async {
    final src = await events(fromScheduleId);
    await _db.transaction((txn) async {
      for (final to in toScheduleIds) {
        if (to == fromScheduleId) continue;
        await txn.delete('bell_events', where: 'schedule_id = ?', whereArgs: [to]);
        for (final e in src) {
          final m = BellEvent(
                  scheduleId: to, type: e.type, minute: e.minute, label: e.label,
                  subject: e.subject, soundId: e.soundId, durationSec: e.durationSec,
                  enabled: e.enabled)
              .toMap()
            ..remove('id');
          await txn.insert('bell_events', m);
        }
        await txn.update('schedules', {'is_working': 1}, where: 'id = ?', whereArgs: [to]);
      }
    });
    await _log.change('نسخ جدول يوم إلى ${toScheduleIds.length} يوم/أيام');
    _onChanged();
  }

  /// يخطط أحداث يوم كامل من معاملات الضبط التلقائي (دون كتابة في القاعدة).
  static ({String? error, List<BellEvent> events}) planDay({
    required int scheduleId,
    required int startMinute,
    required int lessons,
    required int lessonMinutes,
    required int breakAfterLesson,
    required int breakMinutes,
    required int assemblyMinutes,
    String? soundId,
    int durationSec = 5,
  }) {
    const none = <BellEvent>[];
    if (startMinute < 0 || startMinute > 1439) return (error: 'وقت بداية غير صالح', events: none);
    if (lessons < 1 || lessons > 15) return (error: 'عدد الحصص يجب أن يكون بين 1 و15', events: none);
    if (lessonMinutes < 5 || lessonMinutes > 180) {
      return (error: 'مدة الحصة يجب أن تكون بين 5 و180 دقيقة', events: none);
    }
    if (assemblyMinutes < 0 || assemblyMinutes > 120) {
      return (error: 'مدة الطابور يجب أن تكون بين 0 و120 دقيقة', events: none);
    }
    if (breakAfterLesson < 0 || breakAfterLesson >= lessons) {
      return (error: 'الاستراحة تكون بعد حصة من 1 إلى ${lessons - 1} (أو 0 بدون استراحة)', events: none);
    }
    if (breakAfterLesson > 0 && (breakMinutes < 1 || breakMinutes > 120)) {
      return (error: 'مدة الاستراحة يجب أن تكون بين 1 و120 دقيقة', events: none);
    }
    final total = assemblyMinutes + lessons * lessonMinutes + (breakAfterLesson > 0 ? breakMinutes : 0);
    if (startMinute + total > 1439) {
      return (error: 'الجدول يتجاوز منتصف الليل. قلّل عدد الحصص أو قدّم وقت البداية.', events: none);
    }
    BellEvent ev(BellEventType t, int m) =>
        BellEvent(scheduleId: scheduleId, type: t, minute: m, soundId: soundId, durationSec: durationSec);
    final list = <BellEvent>[];
    var t = startMinute;
    list.add(ev(BellEventType.dayStart, t));
    if (assemblyMinutes > 0) {
      list.add(ev(BellEventType.assemblyStart, t));
      t += assemblyMinutes;
      list.add(ev(BellEventType.assemblyEnd, t));
    }
    for (var i = 1; i <= lessons; i++) {
      list.add(ev(BellEventType.lessonStart, t));
      t += lessonMinutes;
      list.add(ev(BellEventType.lessonEnd, t));
      if (i == breakAfterLesson) {
        list.add(ev(BellEventType.breakStart, t));
        t += breakMinutes;
        list.add(ev(BellEventType.breakEnd, t));
      }
    }
    list.add(ev(BellEventType.dayEnd, t));
    return (error: null, events: list);
  }

  /// الضبط التلقائي لعدة أيام دفعة واحدة (يستبدل أحداث الأيام المحددة). يرجع رسالة خطأ أو null.
  Future<String?> quickGenerateDays({
    required List<int> scheduleIds,
    required int startMinute,
    required int lessons,
    required int lessonMinutes,
    required int breakAfterLesson,
    required int breakMinutes,
    required int assemblyMinutes,
    String? soundId,
    int durationSec = 5,
  }) async {
    if (scheduleIds.isEmpty) return 'اختر يومًا واحدًا على الأقل';
    final plans = <int, List<BellEvent>>{};
    for (final id in scheduleIds) {
      final p = planDay(
        scheduleId: id,
        startMinute: startMinute,
        lessons: lessons,
        lessonMinutes: lessonMinutes,
        breakAfterLesson: breakAfterLesson,
        breakMinutes: breakMinutes,
        assemblyMinutes: assemblyMinutes,
        soundId: soundId,
        durationSec: durationSec,
      );
      if (p.error != null) return p.error;
      plans[id] = p.events;
    }
    try {
      await _db.transaction((txn) async {
        for (final entry in plans.entries) {
          await txn.delete('bell_events', where: 'schedule_id = ?', whereArgs: [entry.key]);
          for (final e in entry.value) {
            final m = e.toMap()..remove('id');
            await txn.insert('bell_events', m);
          }
          await txn.update('schedules', {'is_working': 1}, where: 'id = ?', whereArgs: [entry.key]);
        }
      });
    } on DatabaseException catch (e) {
      return 'تعذر تطبيق الضبط التلقائي: $e';
    }
    await _log.change('ضبط تلقائي للجدول على ${scheduleIds.length} يوم/أيام');
    _onChanged();
    return null;
  }

  Future<String?> quickGenerate({
    required int scheduleId,
    required int startMinute,
    required int lessons,
    required int lessonMinutes,
    required int breakAfterLesson,
    required int breakMinutes,
    required int assemblyMinutes,
    String? soundId,
    int durationSec = 5,
  }) =>
      quickGenerateDays(
        scheduleIds: [scheduleId],
        startMinute: startMinute,
        lessons: lessons,
        lessonMinutes: lessonMinutes,
        breakAfterLesson: breakAfterLesson,
        breakMinutes: breakMinutes,
        assemblyMinutes: assemblyMinutes,
        soundId: soundId,
        durationSec: durationSec,
      );

  /// الضبط اليدوي: يحفظ زمن خانة (طابور/حصة/استراحة) من وإلى. يرجع رسالة خطأ أو null.
  Future<String?> saveSlot({
    required int scheduleId,
    required SlotKind kind,
    required int number,
    required int from,
    required int to,
    String? subject,
    String? soundId,
    int durationSec = 5,
    bool enabled = true,
  }) async {
    if (durationSec < 1 || durationSec > 300) return 'مدة الرنين يجب أن تكون بين 1 و300 ثانية';
    final slots = SlotLogic.build(await events(scheduleId));
    final err = SlotLogic.validate(slots, kind, number, from, to);
    if (err != null) return err;
    final cur = slots.where((s) => s.kind == kind && s.number == number).firstOrNull;
    final types = SlotLogic.typesOf(kind);
    BellEvent mk(int? id, BellEventType t, int m, {String? subj}) => BellEvent(
        id: id,
        scheduleId: scheduleId,
        type: t,
        minute: m,
        subject: subj,
        soundId: soundId,
        durationSec: durationSec,
        enabled: enabled);
    final startE = mk(cur?.start?.id, types.$1, from, subj: kind == SlotKind.lesson ? subject : null);
    final endE = mk(cur?.end?.id, types.$2, to);
    try {
      await _db.transaction((txn) async {
        for (final e in [startE, endE]) {
          final m = e.toMap();
          if (e.id == null) {
            m.remove('id');
            await txn.insert('bell_events', m);
          } else {
            await txn.update('bell_events', m, where: 'id = ?', whereArgs: [e.id]);
          }
        }
      });
    } on DatabaseException catch (ex) {
      return 'تعذر الحفظ: $ex';
    }
    final name = SlotInfo(kind: kind, number: number).name;
    await _log.change('ضبط يدوي: $name من ${hm(from)} إلى ${hm(to)}');
    _onChanged();
    return null;
  }

  Future<void> deleteSlot(SlotInfo s) async {
    await _db.transaction((txn) async {
      for (final e in [s.start, s.end]) {
        if (e?.id != null) await txn.delete('bell_events', where: 'id = ?', whereArgs: [e!.id]);
      }
    });
    await _log.change('حذف أوقات: ${s.name}');
    _onChanged();
  }

  /// حالة يوم لمبنى (للعرض في الشاشة الرئيسية).
  Future<DayInfo> dayInfo(int buildingId, DateTime date) async {
    final res = await resolveHoliday(_db, buildingId, date);
    if (res.overrideTitle != null) return DayInfo('override', res.overrideTitle);
    if (res.holidayTitle != null) return DayInfo('holiday', res.holidayTitle);
    final r = await _db.query('schedules',
        where: 'building_id = ? AND day_of_week = ?', whereArgs: [buildingId, date.weekday], limit: 1);
    if (r.isEmpty) return const DayInfo('noSchedule');
    if ((r.first['is_working'] as int? ?? 1) == 0) return const DayInfo('weeklyOff');
    return const DayInfo('normal');
  }
}

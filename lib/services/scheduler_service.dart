import 'package:sqflite/sqflite.dart';

import '../features/lesson_progress/repositories/schedule_day_provider.dart';
import '../models/models.dart';
import '../repositories/log_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/time_utils.dart';
import 'native_bridge.dart';

class ScheduleOutcome {
  const ScheduleOutcome(this.alarms, this.scheduled, this.exactAllowed);
  final List<Map<String, dynamic>> alarms;

  /// عدد المواعيد التي سجّلها نظام Android فعليًا (-1 = فشل).
  final int scheduled;
  final bool exactAllowed;
}

/// يبني قائمة مواعيد الأجراس للأيام القادمة من قاعدة البيانات، ويسلّمها للكود الأصلي.
/// كل استدعاء يلغي المواعيد القديمة كلها ويجدول القائمة الجديدة، فلا تتكرر الأجراس.
class SchedulerService {
  SchedulerService(this._db, this._settings, this._native, this._log, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Database _db;
  final SettingsRepository _settings;
  final NativeBridge _native;
  final LogRepository _log;
  final DateTime Function() _clock;

  static const int horizonDays = 14;
  static const int maxAlarms = 450;

  /// يبني المواعيد دون جدولتها (قابل للاختبار).
  Future<List<Map<String, dynamic>>> plan() async {
    final now = _clock();
    final sounds = {for (final s in await _settings.sounds()) s.id: s.assetPath};
    final usage = (await _settings.get('audio_usage')) == 'media' ? 'media' : 'alarm';
    final fallbackAsset = sounds['bell_classic'] ?? (sounds.values.isEmpty ? '' : sounds.values.first);

    final buildings = await _db.rawQuery('''
      SELECT b.id AS bid, b.name AS bname, b.volume AS volume, b.default_sound AS dsound,
             s.name AS sname
      FROM buildings b JOIN schools s ON s.id = b.school_id
      WHERE s.is_active = 1''');

    final raw = <Map<String, dynamic>>[];
    for (var d = 0; d < horizonDays; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      for (final b in buildings) {
        final bid = b['bid'] as int;
        final res = await resolveHoliday(_db, bid, date);
        final overridden = res.overrideTitle != null;
        if (res.holidayTitle != null && !overridden) continue;
        final sched = await _db.query('schedules',
            where: 'building_id = ? AND day_of_week = ?', whereArgs: [bid, date.weekday], limit: 1);
        if (sched.isEmpty) continue;
        if (!overridden && (sched.first['is_working'] as int? ?? 1) == 0) continue;
        final events = await _db.query('bell_events',
            where: 'schedule_id = ? AND is_enabled = 1', whereArgs: [sched.first['id']]);
        for (final r in events) {
          final e = BellEvent.fromMap(r);
          final at = DateTime(date.year, date.month, date.day, e.minute ~/ 60, e.minute % 60);
          if (!at.isAfter(now)) continue;
          final soundId = e.soundId ?? (b['dsound'] as String?) ?? 'bell_classic';
          raw.add({
            'local': '${ymd(date)} ${hm(e.minute)}',
            'date': ymd(date),
            'eventId': e.id,
            'eventIds': [e.id],
            'priority': isEndType(e.type) ? 0 : 1,
            'buildingId': bid,
            'schoolName': b['sname'],
            'buildingName': b['bname'],
            'label': (e.label != null && e.label!.trim().isNotEmpty) ? e.label : bellTypeLabel(e.type),
            'sound': sounds[soundId] ?? fallbackAsset,
            'durationSec': e.durationSec,
            'volume': (b['volume'] as num? ?? 1.0).toDouble(),
            'usage': usage,
          });
        }
      }
    }
    return finalize(raw);
  }

  /// يدمج الأحداث المتزامنة في المبنى نفسه (جرس واحد)، ويرتّب ويعطي أرقام طلب فريدة.
  static List<Map<String, dynamic>> finalize(List<Map<String, dynamic>> raw) {
    raw.sort((a, b) {
      final c = (a['local'] as String).compareTo(b['local'] as String);
      if (c != 0) return c;
      final c2 = (a['buildingId'] as int).compareTo(b['buildingId'] as int);
      if (c2 != 0) return c2;
      final c3 = (a['priority'] as int).compareTo(b['priority'] as int);
      if (c3 != 0) return c3;
      return (a['eventId'] as int).compareTo(b['eventId'] as int);
    });
    final out = <Map<String, dynamic>>[];
    for (final m in raw) {
      if (out.isNotEmpty &&
          out.last['local'] == m['local'] &&
          out.last['buildingId'] == m['buildingId']) {
        (out.last['eventIds'] as List).addAll(m['eventIds'] as List);
        continue;
      }
      out.add(Map<String, dynamic>.from(m));
    }
    final limited = out.length > maxAlarms ? out.sublist(0, maxAlarms) : out;
    for (var i = 0; i < limited.length; i++) {
      limited[i]['id'] = i + 1;
      limited[i].remove('priority');
    }
    return limited;
  }

  /// [reason]: startup | change | resume — للتسجيل فقط.
  Future<ScheduleOutcome> rebuild({String reason = 'resume'}) async {
    final exact = await _native.canScheduleExact();
    List<Map<String, dynamic>> alarms;
    try {
      alarms = await plan();
    } catch (e) {
      await _log.error('فشل بناء قائمة الأجراس: $e');
      return ScheduleOutcome(const [], -1, exact);
    }
    final n = await _native.scheduleAlarms(alarms);
    if (n < 0) {
      await _log.error('فشلت جدولة الأجراس في نظام Android');
    } else if (reason != 'resume') {
      await _log.schedule(
          'أُعيدت جدولة $n جرسًا (إلغاء المواعيد القديمة) بعد ${reason == 'change' ? 'تعديل البيانات' : 'تشغيل التطبيق'}');
      if (!exact) {
        await _log.schedule('الجدولة غير دقيقة: صلاحية التنبيهات الدقيقة غير ممنوحة', result: 'error');
      }
    }
    return ScheduleOutcome(alarms, n, exact);
  }
}

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_school_bell/features/lesson_progress/models/lesson_progress_models.dart';
import 'package:smart_school_bell/services/backup_service.dart';
import 'package:smart_school_bell/services/scheduler_service.dart';
import 'package:smart_school_bell/utils/time_utils.dart';

Map<String, dynamic> alarm(String local, int building, int event, {int priority = 1}) => {
      'local': local,
      'date': local.substring(0, 10),
      'eventId': event,
      'eventIds': [event],
      'priority': priority,
      'buildingId': building,
    };

Map<String, dynamic> validBackup() => {
      'app': 'smart_school_bell',
      'version': 1,
      'tables': {
        'schools': [
          {'id': 1, 'name': 'مدرسة', 'is_active': 1}
        ],
        'buildings': [
          {'id': 1, 'school_id': 1, 'name': 'مبنى', 'volume': 1.0}
        ],
        'schedules': [
          {'id': 1, 'building_id': 1, 'day_of_week': 1, 'is_working': 1}
        ],
        'bell_events': [
          {'id': 1, 'schedule_id': 1, 'event_type': 'lessonStart', 'event_time': '08:00', 'duration_sec': 5}
        ],
        'holidays': [
          {'id': 1, 'school_id': 1, 'title': 'عطلة', 'start_date': '2026-10-01', 'end_date': '2026-10-03'}
        ],
      },
    };

void main() {
  group('SchedulerService.finalize', () {
    test('يدمج الأحداث المتزامنة في المبنى نفسه بجرس واحد ويحفظ كل المعرّفات', () {
      final out = SchedulerService.finalize([
        alarm('2026-10-18 08:45', 1, 10, priority: 1),
        alarm('2026-10-18 08:45', 1, 11, priority: 0),
      ]);
      expect(out.length, 1);
      expect(out.first['eventIds'], containsAll([10, 11]));
      expect(out.first['eventId'], 11); // حدث النهاية أولًا
    });

    test('لا يدمج أجراس مبنيين مختلفين في الدقيقة نفسها', () {
      final out = SchedulerService.finalize([
        alarm('2026-10-18 08:45', 1, 10),
        alarm('2026-10-18 08:45', 2, 20),
      ]);
      expect(out.length, 2);
    });

    test('أرقام الطلب فريدة ومتسلسلة والترتيب زمني', () {
      final out = SchedulerService.finalize([
        alarm('2026-10-19 07:00', 1, 3),
        alarm('2026-10-18 07:00', 1, 1),
        alarm('2026-10-18 07:45', 1, 2),
      ]);
      expect(out.map((e) => e['id']), [1, 2, 3]);
      expect(out.map((e) => e['eventId']), [1, 2, 3]);
    });

    test('يحدّ عدد المواعيد بالحد الأقصى', () {
      final raw = [
        for (var i = 0; i < SchedulerService.maxAlarms + 50; i++)
          alarm('2026-11-${two(1 + i ~/ 40)} ${two(i % 24)}:${two(i % 60)}', 1, i + 1),
      ];
      expect(SchedulerService.finalize(raw).length <= SchedulerService.maxAlarms, true);
    });
  });

  group('BackupService.validate', () {
    test('نسخة سليمة', () => expect(BackupService.validate(validBackup()), isNull));

    test('ملف ليس نسخة للتطبيق', () {
      expect(BackupService.validate({'app': 'other', 'version': 1}), isNotNull);
    });

    test('إصدار أحدث من المدعوم', () {
      final b = validBackup()..['version'] = 99;
      expect(BackupService.validate(b), isNotNull);
    });

    test('مبنى يشير إلى مدرسة غير موجودة', () {
      final b = validBackup();
      (b['tables'] as Map)['buildings'] = [
        {'id': 1, 'school_id': 77, 'name': 'مبنى'}
      ];
      expect(BackupService.validate(b), isNotNull);
    });

    test('وقت حدث غير صالح', () {
      final b = validBackup();
      ((b['tables'] as Map)['bell_events'] as List)[0]['event_time'] = '25:99';
      expect(BackupService.validate(b), isNotNull);
    });

    test('إجازة نهايتها قبل بدايتها', () {
      final b = validBackup();
      ((b['tables'] as Map)['holidays'] as List)[0]['end_date'] = '2026-09-01';
      expect(BackupService.validate(b), isNotNull);
    });

    test('بيانات ليست Map', () => expect(BackupService.validate([1, 2]), isNotNull));
  });

  group('SegmentBuilder + استبدال الأيام', () {
    test('جداول أيام مختلفة تعطي فترات مختلفة', () {
      final d1 = DateTime(2026, 10, 18);
      final d2 = DateTime(2026, 10, 19);
      final a = SegmentBuilder.build(d1, const [
        BellEventInput(id: 1, type: BellEventType.lessonStart, minuteOfDay: 480),
        BellEventInput(id: 2, type: BellEventType.lessonEnd, minuteOfDay: 525),
      ]);
      final b = SegmentBuilder.build(d2, const [
        BellEventInput(id: 3, type: BellEventType.lessonStart, minuteOfDay: 600),
        BellEventInput(id: 4, type: BellEventType.lessonEnd, minuteOfDay: 660),
      ]);
      expect(a.single.total, const Duration(minutes: 45));
      expect(b.single.total, const Duration(minutes: 60));
      expect(a.single.start.day, 18);
      expect(b.single.start.day, 19);
    });
  });

  group('time_utils', () {
    test('parseHm', () {
      expect(parseHm('08:45'), 525);
      expect(parseHm('24:00'), isNull);
      expect(parseHm('abc'), isNull);
    });
    test('parseYmd يرفض تاريخًا غير موجود', () {
      expect(parseYmd('2026-02-30'), isNull);
      expect(parseYmd('2026-10-17'), DateTime(2026, 10, 17));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_school_bell/features/lesson_progress/models/lesson_progress_models.dart';
import 'package:smart_school_bell/models/models.dart';
import 'package:smart_school_bell/repositories/schedule_repository.dart';
import 'package:smart_school_bell/repositories/slot_logic.dart';

BellEvent ev(int id, BellEventType t, int minute) =>
    BellEvent(id: id, scheduleId: 1, type: t, minute: minute);

void main() {
  // الطابور 07:30-07:40 | حصة1 07:40-08:25 | حصة2 08:25-09:10
  final events = [
    ev(1, BellEventType.assemblyStart, 450),
    ev(2, BellEventType.assemblyEnd, 460),
    ev(3, BellEventType.lessonStart, 460),
    ev(4, BellEventType.lessonEnd, 505),
    ev(5, BellEventType.lessonStart, 505),
    ev(6, BellEventType.lessonEnd, 550),
  ];

  group('SlotLogic.build', () {
    test('يبني الطابور والحصص ويكمل خمس حصص على الأقل', () {
      final slots = SlotLogic.build(events);
      final lessons = slots.where((s) => s.kind == SlotKind.lesson).toList();
      expect(lessons.length, 5);
      expect(lessons[0].from, 460);
      expect(lessons[0].to, 505);
      expect(lessons[1].from, 505);
      expect(lessons[1].to, 550);
      expect(lessons[2].isSet, false);
      expect(slots.firstWhere((s) => s.kind == SlotKind.assembly).isSet, true);
    });

    test('حصتان متلاصقتان: نهاية الأولى لا تُنسب للثانية', () {
      final lessons = SlotLogic.build(events).where((s) => s.kind == SlotKind.lesson).toList();
      expect(lessons[0].end!.id, 4);
      expect(lessons[1].end!.id, 6);
    });

    test('أسماء الحصص بالعربية', () {
      final lessons = SlotLogic.build(const []).where((s) => s.kind == SlotKind.lesson).toList();
      expect(lessons.first.name, 'الحصة الأولى');
      expect(lessons.last.name, 'الحصة الخامسة');
    });
  });

  group('SlotLogic.validate', () {
    final slots = SlotLogic.build(events);

    test('وقت نهاية قبل البداية مرفوض', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 3, 600, 590), isNotNull);
    });

    test('حصة ثالثة صحيحة بعد الثانية', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 3, 550, 595), isNull);
    });

    test('تعارض مع حصة موجودة', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 3, 540, 590), isNotNull);
    });

    test('ضبط الحصة الرابعة قبل الثالثة مرفوض (الترتيب)', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 4, 600, 645), isNotNull);
    });

    test('تعديل الحصة الأولى لتبدأ بعد الثانية مرفوض', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 1, 520, 560), isNotNull);
    });

    test('تعديل الحصة الأولى داخل حدودها مقبول', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 1, 465, 505), isNull);
    });

    test('نهاية متأخرة تتجاوز منتصف الليل مرفوضة', () {
      expect(SlotLogic.validate(slots, SlotKind.lesson, 3, 1400, 1500), isNotNull);
    });
  });

  group('ScheduleRepository.planDay', () {
    test('سبع حصص مع استراحة بعد الثالثة', () {
      final p = ScheduleRepository.planDay(
        scheduleId: 1,
        startMinute: 420,
        lessons: 7,
        lessonMinutes: 45,
        breakAfterLesson: 3,
        breakMinutes: 20,
        assemblyMinutes: 10,
      );
      expect(p.error, isNull);
      expect(p.events.where((e) => e.type == BellEventType.lessonStart).length, 7);
      expect(p.events.where((e) => e.type == BellEventType.breakStart).length, 1);
      expect(p.events.first.type, BellEventType.dayStart);
      expect(p.events.last.type, BellEventType.dayEnd);
      // 07:00 + 10 + 7*45 + 20 = 12:45 => 765
      expect(p.events.last.minute, 420 + 10 + 7 * 45 + 20);
    });

    test('يرفض الجدول العابر لمنتصف الليل', () {
      final p = ScheduleRepository.planDay(
        scheduleId: 1,
        startMinute: 1300,
        lessons: 5,
        lessonMinutes: 45,
        breakAfterLesson: 0,
        breakMinutes: 0,
        assemblyMinutes: 0,
      );
      expect(p.error, isNotNull);
    });

    test('يرفض استراحة بعد آخر حصة', () {
      final p = ScheduleRepository.planDay(
        scheduleId: 1,
        startMinute: 420,
        lessons: 3,
        lessonMinutes: 45,
        breakAfterLesson: 3,
        breakMinutes: 20,
        assemblyMinutes: 0,
      );
      expect(p.error, isNotNull);
    });

    test('الحصص الناتجة تُقرأ كخانات سليمة', () {
      final p = ScheduleRepository.planDay(
        scheduleId: 1,
        startMinute: 480,
        lessons: 5,
        lessonMinutes: 40,
        breakAfterLesson: 0,
        breakMinutes: 0,
        assemblyMinutes: 0,
      );
      final events = [for (var i = 0; i < p.events.length; i++) ev(i + 1, p.events[i].type, p.events[i].minute)];
      final lessons = SlotLogic.build(events).where((s) => s.kind == SlotKind.lesson).toList();
      expect(lessons.every((s) => s.isSet), true);
      expect(lessons.last.to, 480 + 5 * 40);
    });
  });
}

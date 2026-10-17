import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

enum SlotKind { assembly, lesson, breakTime }

const List<String> _ordinals = [
  'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة',
  'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة',
];

/// خانة زمنية في يوم واحد: الطابور، حصة، أو استراحة، بحدثَي بداية ونهاية.
class SlotInfo {
  const SlotInfo({required this.kind, required this.number, this.start, this.end});

  final SlotKind kind;
  final int number;
  final BellEvent? start;
  final BellEvent? end;

  int? get from => start?.minute;
  int? get to => end?.minute;
  bool get isSet => start != null && end != null;
  bool get enabled => (start?.enabled ?? true) && (end?.enabled ?? true);

  String get name => switch (kind) {
        SlotKind.assembly => 'الطابور الصباحي',
        SlotKind.lesson => 'الحصة ${number <= _ordinals.length ? _ordinals[number - 1] : 'رقم $number'}',
        SlotKind.breakTime => 'الاستراحة $number',
      };

  String get rangeText => isSet
      ? 'من ${hm(from!)} إلى ${hm(to!)}'
      : (start != null ? 'غير مكتملة (ينقصها وقت النهاية)' : 'لم يُضبط بعد');
}

class SlotLogic {
  static (BellEventType, BellEventType) typesOf(SlotKind k) => switch (k) {
        SlotKind.assembly => (BellEventType.assemblyStart, BellEventType.assemblyEnd),
        SlotKind.lesson => (BellEventType.lessonStart, BellEventType.lessonEnd),
        SlotKind.breakTime => (BellEventType.breakStart, BellEventType.breakEnd),
      };

  /// يبني الخانات من أحداث اليوم. الأرقام حسب ترتيب الزمن.
  /// تظهر دائمًا خانة الطابور و[minLessons] حصة على الأقل (الفارغة تُعرض «لم يُضبط»).
  static List<SlotInfo> build(List<BellEvent> events, {int minLessons = 5}) {
    final a = typesOf(SlotKind.assembly);
    final l = typesOf(SlotKind.lesson);
    final b = typesOf(SlotKind.breakTime);
    return [
      ..._pair(SlotKind.assembly, events, a.$1, a.$2, min: 1, limit: 1),
      ..._pair(SlotKind.lesson, events, l.$1, l.$2, min: minLessons),
      ..._pair(SlotKind.breakTime, events, b.$1, b.$2, min: 0),
    ];
  }

  static List<SlotInfo> _pair(
    SlotKind kind,
    List<BellEvent> events,
    BellEventType st,
    BellEventType en, {
    required int min,
    int? limit,
  }) {
    final starts = events.where((e) => e.type == st).toList()..sort((x, y) => x.minute.compareTo(y.minute));
    final ends = events.where((e) => e.type == en).toList()..sort((x, y) => x.minute.compareTo(y.minute));
    final used = <BellEvent>{};
    final out = <SlotInfo>[];
    var n = starts.length;
    if (limit != null && n > limit) n = limit;
    for (var i = 0; i < n; i++) {
      final s = starts[i];
      final nextStart = i + 1 < starts.length ? starts[i + 1].minute : 100000;
      BellEvent? end;
      for (final e in ends) {
        if (used.contains(e)) continue;
        if (e.minute > s.minute && e.minute <= nextStart) {
          end = e;
          used.add(e);
          break;
        }
      }
      out.add(SlotInfo(kind: kind, number: i + 1, start: s, end: end));
    }
    for (var i = n; i < min; i++) {
      out.add(SlotInfo(kind: kind, number: i + 1));
    }
    return out;
  }

  /// يرجع رسالة خطأ عربية أو null. لا يدعم الجداول العابرة لمنتصف الليل.
  static String? validate(List<SlotInfo> slots, SlotKind kind, int number, int from, int to) {
    if (from < 0 || to > 1439) return 'وقت غير صالح';
    if (to <= from) {
      return 'وقت النهاية يجب أن يكون بعد وقت البداية (الجداول العابرة لمنتصف الليل غير مدعومة)';
    }
    final cur = slots.where((s) => s.kind == kind && s.number == number).firstOrNull;
    final setSame = slots.where((s) => s.kind == kind && s.isSet).toList();

    if (kind != SlotKind.assembly && (cur == null || !cur.isSet) && number != setSame.length + 1) {
      return 'اضبط ${kind == SlotKind.lesson ? 'الحصص' : 'الاستراحات'} بالترتيب: '
          'التالية المتاحة هي رقم ${setSame.length + 1}';
    }

    for (final o in slots) {
      if (!o.isSet || (o.kind == kind && o.number == number)) continue;
      if (from < o.to! && o.from! < to) {
        return 'يتعارض مع ${o.name} (${hm(o.from!)} - ${hm(o.to!)})';
      }
    }

    if (kind != SlotKind.assembly) {
      for (final o in slots) {
        if (!o.isSet || o.kind != kind || o.number == number) continue;
        if (o.number < number && from < o.to!) return 'يجب أن تبدأ بعد نهاية ${o.name}';
        if (o.number > number && to > o.from!) return 'يجب أن تنتهي قبل بداية ${o.name}';
      }
    }
    return null;
  }
}

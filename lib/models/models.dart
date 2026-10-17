import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../utils/time_utils.dart';

String bellTypeLabel(BellEventType t) => switch (t) {
      BellEventType.dayStart => 'بداية الدوام',
      BellEventType.assemblyStart => 'الطابور الصباحي',
      BellEventType.assemblyEnd => 'نهاية الطابور',
      BellEventType.lessonStart => 'بداية حصة',
      BellEventType.lessonEnd => 'نهاية حصة',
      BellEventType.breakStart => 'بداية الاستراحة',
      BellEventType.breakEnd => 'نهاية الاستراحة',
      BellEventType.dayEnd => 'نهاية الدوام',
    };

bool isEndType(BellEventType t) =>
    t == BellEventType.lessonEnd ||
    t == BellEventType.breakEnd ||
    t == BellEventType.dayEnd ||
    t == BellEventType.assemblyEnd;

class School {
  const School({this.id, required this.name, this.address, this.isActive = true});
  final int? id;
  final String name;
  final String? address;
  final bool isActive;

  factory School.fromMap(Map<String, Object?> m) => School(
        id: m['id'] as int?,
        name: m['name'] as String,
        address: m['address'] as String?,
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name.trim(),
        'address': (address == null || address!.trim().isEmpty) ? null : address!.trim(),
        'is_active': isActive ? 1 : 0,
      };
}

class Building {
  const Building({this.id, required this.schoolId, required this.name, this.volume = 1.0, this.defaultSound});
  final int? id;
  final int schoolId;
  final String name;
  final double volume;
  final String? defaultSound;

  factory Building.fromMap(Map<String, Object?> m) => Building(
        id: m['id'] as int?,
        schoolId: m['school_id'] as int,
        name: m['name'] as String,
        volume: (m['volume'] as num? ?? 1.0).toDouble(),
        defaultSound: m['default_sound'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'school_id': schoolId,
        'name': name.trim(),
        'volume': volume.clamp(0.0, 1.0),
        'default_sound': defaultSound,
      };
}

/// مبنى مع اسم مدرسته (للاختيار والعرض).
class BuildingRef {
  const BuildingRef(this.building, this.schoolName, this.schoolActive);
  final Building building;
  final String schoolName;
  final bool schoolActive;
  String get title => '$schoolName - ${building.name}';
}

class ScheduleDay {
  const ScheduleDay({required this.id, required this.buildingId, required this.dayOfWeek, required this.isWorking});
  final int id;
  final int buildingId;
  final int dayOfWeek;
  final bool isWorking;

  factory ScheduleDay.fromMap(Map<String, Object?> m) => ScheduleDay(
        id: m['id'] as int,
        buildingId: m['building_id'] as int,
        dayOfWeek: m['day_of_week'] as int,
        isWorking: (m['is_working'] as int? ?? 1) == 1,
      );
}

class BellEvent {
  const BellEvent({
    this.id,
    required this.scheduleId,
    required this.type,
    required this.minute,
    this.label,
    this.subject,
    this.soundId,
    this.durationSec = 5,
    this.enabled = true,
  });

  final int? id;
  final int scheduleId;
  final BellEventType type;
  final int minute;
  final String? label;
  final String? subject;
  final String? soundId;
  final int durationSec;
  final bool enabled;

  factory BellEvent.fromMap(Map<String, Object?> m) => BellEvent(
        id: m['id'] as int?,
        scheduleId: m['schedule_id'] as int,
        type: BellEventType.values.firstWhere(
          (t) => t.name == m['event_type'],
          orElse: () => BellEventType.lessonStart,
        ),
        minute: parseHm(m['event_time'] as String?) ?? 0,
        label: m['label'] as String?,
        subject: m['subject'] as String?,
        soundId: m['sound_id'] as String?,
        durationSec: m['duration_sec'] as int? ?? 5,
        enabled: (m['is_enabled'] as int? ?? 1) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'schedule_id': scheduleId,
        'event_type': type.name,
        'event_time': hm(minute),
        'label': (label == null || label!.trim().isEmpty) ? null : label!.trim(),
        'subject': (subject == null || subject!.trim().isEmpty) ? null : subject!.trim(),
        'sound_id': soundId,
        'duration_sec': durationSec,
        'is_enabled': enabled ? 1 : 0,
      };

  BellEvent copyWith({bool? enabled}) => BellEvent(
        id: id,
        scheduleId: scheduleId,
        type: type,
        minute: minute,
        label: label,
        subject: subject,
        soundId: soundId,
        durationSec: durationSec,
        enabled: enabled ?? this.enabled,
      );
}

const Map<String, String> holidayKindLabels = {
  'official': 'إجازة رسمية',
  'school': 'إجازة المدرسة',
  'exceptional': 'عطلة استثنائية',
  'override': 'يوم دوام استثنائي (يلغي التعطيل)',
};

class Holiday {
  const Holiday({
    this.id,
    required this.schoolId,
    this.buildingId,
    required this.title,
    this.kind = 'official',
    this.notes,
    required this.start,
    required this.end,
    this.active = true,
  });

  final int? id;
  final int schoolId;
  final int? buildingId;
  final String title;
  final String kind;
  final String? notes;
  final DateTime start;
  final DateTime end;
  final bool active;

  factory Holiday.fromMap(Map<String, Object?> m) => Holiday(
        id: m['id'] as int?,
        schoolId: m['school_id'] as int,
        buildingId: m['building_id'] as int?,
        title: m['title'] as String,
        kind: m['kind'] as String? ?? 'official',
        notes: m['notes'] as String?,
        start: parseYmd(m['start_date'] as String?) ?? DateTime.now(),
        end: parseYmd(m['end_date'] as String?) ?? DateTime.now(),
        active: (m['is_active'] as int? ?? 1) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'school_id': schoolId,
        'building_id': buildingId,
        'title': title.trim(),
        'kind': kind,
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
        'start_date': ymd(start),
        'end_date': ymd(end),
        'is_active': active ? 1 : 0,
      };
}

class SoundProfile {
  const SoundProfile(this.id, this.name, this.assetPath);
  final String id;
  final String name;
  final String assetPath;
  factory SoundProfile.fromMap(Map<String, Object?> m) =>
      SoundProfile(m['id'] as String, m['name'] as String, m['asset_path'] as String);
}

class LogEntry {
  const LogEntry({
    required this.id,
    required this.ts,
    required this.kind,
    this.schoolName,
    this.buildingName,
    this.eventLabel,
    this.scheduledDate,
    this.mode,
    this.result,
    this.message,
  });
  final int id;
  final DateTime ts;
  final String kind;
  final String? schoolName;
  final String? buildingName;
  final String? eventLabel;
  final String? scheduledDate;
  final String? mode;
  final String? result;
  final String? message;

  factory LogEntry.fromMap(Map<String, Object?> m) => LogEntry(
        id: m['id'] as int,
        ts: DateTime.tryParse(m['ts'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        kind: m['log_kind'] as String? ?? 'bell',
        schoolName: m['school_name'] as String?,
        buildingName: m['building_name'] as String?,
        eventLabel: m['event_label'] as String?,
        scheduledDate: m['scheduled_date'] as String?,
        mode: m['mode'] as String?,
        result: m['result'] as String?,
        message: m['message'] as String?,
      );
}

/// حالة يوم لمبنى: دوام عادي، إجازة، يوم دوام استثنائي، عطلة أسبوعية، لا يوجد جدول.
class DayInfo {
  const DayInfo(this.kind, [this.title]);
  final String kind; // normal | holiday | override | weeklyOff | noSchedule
  final String? title;

  String get label => switch (kind) {
        'holiday' => 'إجازة${title == null ? '' : ': $title'}',
        'override' => 'يوم دوام استثنائي${title == null ? '' : ': $title'}',
        'weeklyOff' => 'عطلة أسبوعية',
        'noSchedule' => 'لا يوجد جدول لهذا اليوم',
        _ => 'دوام عادي',
      };
}

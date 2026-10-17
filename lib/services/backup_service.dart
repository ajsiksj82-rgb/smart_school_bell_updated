import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../utils/time_utils.dart';

class RestoreResult {
  const RestoreResult({this.error, this.warnings = const []});
  final String? error;
  final List<String> warnings;
  bool get ok => error == null;
}

class BackupService {
  BackupService(this._db, this._onChanged, {Future<Directory> Function()? dirProvider})
      : _dirProvider = dirProvider;

  final Database _db;
  final void Function() _onChanged;
  final Future<Directory> Function()? _dirProvider;

  static const int formatVersion = 1;
  static const List<String> _tables = ['schools', 'buildings', 'schedules', 'bell_events', 'holidays'];

  Future<Directory> backupDir() async {
    if (_dirProvider != null) return _dirProvider();
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'backups'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Map<String, dynamic>> buildExport() async {
    final tables = <String, dynamic>{};
    for (final t in _tables) {
      tables[t] = await _db.query(t, orderBy: 'id');
    }
    final settings = await _db.query('app_settings',
        where: "key != 'selected_building'");
    return {
      'app': 'smart_school_bell',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'settings': settings,
    };
  }

  Future<File> export() async {
    final dir = await backupDir();
    final now = DateTime.now();
    final name = 'ssb_backup_${ymd(now)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
    final f = File(p.join(dir.path, name));
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(await buildExport()));
    return f;
  }

  Future<List<File>> list() async {
    final dir = await backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// يرجع رسالة الخطأ إن كانت البيانات غير صالحة، أو null.
  static String? validate(dynamic data, {Set<String> knownSounds = const {}}) {
    if (data is! Map) return 'تنسيق الملف غير صحيح';
    if (data['app'] != 'smart_school_bell') return 'هذا الملف ليس نسخة احتياطية لتطبيق الجرس المدرسي';
    if (data['version'] is! int) return 'إصدار النسخة غير معروف';
    if ((data['version'] as int) > formatVersion) {
      return 'النسخة أحدث من إصدار التطبيق الحالي ولا يمكن استعادتها';
    }
    final t = data['tables'];
    if (t is! Map) return 'جداول البيانات مفقودة';

    List<Map> rows(String name) {
      final v = t[name];
      if (v is! List) throw FormatException('الجدول $name مفقود');
      return v.map((e) {
        if (e is! Map) throw FormatException('صف غير صالح في $name');
        return e;
      }).toList();
    }

    try {
      final schools = rows('schools');
      final buildings = rows('buildings');
      final schedules = rows('schedules');
      final events = rows('bell_events');
      final holidays = rows('holidays');

      final schoolIds = <int>{};
      for (final r in schools) {
        if (r['id'] is! int || r['name'] is! String || (r['name'] as String).trim().isEmpty) {
          return 'بيانات مدرسة غير صالحة';
        }
        schoolIds.add(r['id'] as int);
      }
      final buildingIds = <int>{};
      for (final r in buildings) {
        if (r['id'] is! int || r['name'] is! String || !schoolIds.contains(r['school_id'])) {
          return 'مبنى يشير إلى مدرسة غير موجودة';
        }
        final v = r['volume'];
        if (v != null && (v is! num || v < 0 || v > 1)) return 'مستوى صوت غير صالح';
        buildingIds.add(r['id'] as int);
      }
      final scheduleIds = <int>{};
      final dayKeys = <String>{};
      for (final r in schedules) {
        final dw = r['day_of_week'];
        if (r['id'] is! int || !buildingIds.contains(r['building_id']) || dw is! int || dw < 1 || dw > 7) {
          return 'جدول يوم غير صالح';
        }
        if (!dayKeys.add('${r['building_id']}_$dw')) return 'جدول مكرر لليوم نفسه';
        scheduleIds.add(r['id'] as int);
      }
      final types = BellEventType.values.map((e) => e.name).toSet();
      for (final r in events) {
        if (r['id'] is! int || !scheduleIds.contains(r['schedule_id'])) return 'حدث يشير إلى جدول غير موجود';
        if (!types.contains(r['event_type'])) return 'نوع حدث غير معروف';
        if (parseHm(r['event_time'] as String?) == null) return 'وقت حدث غير صالح';
        final d = r['duration_sec'];
        if (d != null && (d is! int || d < 1 || d > 300)) return 'مدة رنين غير صالحة';
      }
      for (final r in holidays) {
        if (r['id'] is! int || !schoolIds.contains(r['school_id'])) return 'إجازة تشير إلى مدرسة غير موجودة';
        final b = r['building_id'];
        if (b != null && !buildingIds.contains(b)) return 'إجازة تشير إلى مبنى غير موجود';
        final s = parseYmd(r['start_date'] as String?);
        final e = parseYmd(r['end_date'] as String?);
        if (s == null || e == null || e.isBefore(s)) return 'تواريخ إجازة غير صالحة';
        if ((r['title'] as String?)?.trim().isEmpty ?? true) return 'إجازة بلا اسم';
      }
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'بيانات النسخة تالفة';
    }
    return null;
  }

  Future<RestoreResult> restoreFrom(File file, {required Set<String> knownSounds}) async {
    dynamic data;
    try {
      data = jsonDecode(await file.readAsString());
    } catch (_) {
      return const RestoreResult(error: 'تعذرت قراءة الملف أو أنه ليس JSON صالحًا');
    }
    final err = validate(data, knownSounds: knownSounds);
    if (err != null) return RestoreResult(error: err);
    return restoreData(data as Map, knownSounds: knownSounds);
  }

  /// يستبدل البيانات الحالية داخل معاملة واحدة: عند أي خطأ تبقى البيانات الحالية كما هي.
  Future<RestoreResult> restoreData(Map data, {required Set<String> knownSounds}) async {
    final warnings = <String>[];
    try {
      await _db.transaction((txn) async {
        for (final t in _tables.reversed) {
          await txn.delete(t);
        }
        for (final t in _tables) {
          for (final row in (data['tables'][t] as List)) {
            final m = Map<String, Object?>.from(row as Map);
            if (t == 'bell_events') {
              final s = m['sound_id'];
              if (s != null && !knownSounds.contains(s)) {
                m['sound_id'] = null;
                warnings.add('صوت غير موجود (${s}) تم استبداله بالصوت الافتراضي');
              }
            }
            if (t == 'buildings') {
              final s = m['default_sound'];
              if (s != null && !knownSounds.contains(s)) {
                m['default_sound'] = null;
                warnings.add('صوت افتراضي غير موجود (${s}) تم تفريغه');
              }
            }
            await txn.insert(t, m);
          }
        }
        await txn.delete('app_settings', where: "key = 'selected_building'");
        for (final s in (data['settings'] as List? ?? const [])) {
          if (s is Map && s['key'] == 'audio_usage' && s['value'] is String) {
            await txn.insert('app_settings', {'key': 'audio_usage', 'value': s['value']},
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    } catch (e) {
      return RestoreResult(error: 'فشلت الاستعادة، وبقيت البيانات الحالية كما هي ($e)');
    }
    _onChanged();
    return RestoreResult(warnings: warnings.toSet().toList());
  }
}

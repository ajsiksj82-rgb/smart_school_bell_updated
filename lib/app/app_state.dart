import 'dart:async';

import 'package:flutter/widgets.dart';

import '../database/app_database.dart';
import '../features/lesson_progress/repositories/schedule_day_provider.dart';
import '../models/models.dart';
import '../repositories/holiday_repository.dart';
import '../repositories/log_repository.dart';
import '../repositories/school_repository.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/backup_service.dart';
import '../services/native_bridge.dart';
import '../services/scheduler_service.dart';
import '../utils/time_utils.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this.database, {NativeBridge? native}) : native = native ?? NativeBridge() {
    final db = database.db;
    logs = LogRepository(db);
    settings = SettingsRepository(db);
    schools = SchoolRepository(db, logs, dataChanged);
    schedule = ScheduleRepository(db, logs, dataChanged);
    holidays = HolidayRepository(db, logs, dataChanged);
    scheduler = SchedulerService(db, settings, this.native, logs);
    backup = BackupService(db, dataChanged);
    dayProvider = SqliteScheduleDayProvider(db, beforeLogQuery: syncNativeLogs);
  }

  final AppDatabase database;
  final NativeBridge native;
  late final LogRepository logs;
  late final SettingsRepository settings;
  late final SchoolRepository schools;
  late final ScheduleRepository schedule;
  late final HolidayRepository holidays;
  late final SchedulerService scheduler;
  late final BackupService backup;
  late final SqliteScheduleDayProvider dayProvider;

  // الحالة المعروضة
  BuildingRef? selected;
  List<SoundProfile> sounds = [];
  List<Map<String, dynamic>> alarms = [];
  int scheduledCount = 0;
  bool exactAllowed = true;
  bool batteryIgnored = false;
  String audioRoute = 'unknown';
  String audioUsage = 'alarm';
  bool ringing = false;
  DayInfo? dayInfo;
  bool _disposed = false;

  Timer? _debounce;
  Timer? _midnight;
  Timer? _ringTimer;
  bool _rebuilding = false;
  bool _rebuildAgain = false;
  String _pendingReason = 'resume';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    sounds = await settings.sounds();
    audioUsage = (await settings.get('audio_usage')) == 'media' ? 'media' : 'alarm';
    await _restoreSelection();
    await refreshStatus();
    await syncNativeLogs();
    await rebuildSchedule(reason: 'startup');
    await refreshDayInfo();
    _armMidnight();
  }

  Future<void> _restoreSelection() async {
    final refs = await schools.allBuildingRefs();
    if (refs.isEmpty) {
      selected = null;
      return;
    }
    final saved = int.tryParse(await settings.get('selected_building') ?? '');
    selected = refs.firstWhere((r) => r.building.id == saved, orElse: () => refs.first);
  }

  Future<void> selectBuilding(int buildingId) async {
    final refs = await schools.allBuildingRefs();
    final found = refs.where((r) => r.building.id == buildingId);
    if (found.isEmpty) return;
    selected = found.first;
    await settings.set('selected_building', '$buildingId');
    await refreshDayInfo();
    _notify();
  }

  /// يُستدعى من المستودعات بعد أي تعديل: يحدّث الواجهة وشريط الحصة ويعيد الجدولة.
  void dataChanged() {
    dayProvider.notifyChanged();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      await _restoreSelectionKeepingCurrent();
      await rebuildSchedule(reason: 'change');
      await refreshDayInfo();
    });
    _notify();
  }

  Future<void> _restoreSelectionKeepingCurrent() async {
    final refs = await schools.allBuildingRefs();
    if (refs.isEmpty) {
      selected = null;
    } else {
      final cur = selected?.building.id;
      selected = refs.firstWhere((r) => r.building.id == cur, orElse: () => refs.first);
      await settings.set('selected_building', '${selected!.building.id}');
    }
    _notify();
  }

  Future<void> rebuildSchedule({String reason = 'resume'}) async {
    if (_rebuilding) {
      _rebuildAgain = true;
      if (reason != 'resume') _pendingReason = reason;
      return;
    }
    _rebuilding = true;
    try {
      final out = await scheduler.rebuild(reason: reason);
      alarms = out.alarms;
      scheduledCount = out.scheduled;
      exactAllowed = out.exactAllowed;
    } finally {
      _rebuilding = false;
    }
    _notify();
    if (_rebuildAgain) {
      _rebuildAgain = false;
      final r = _pendingReason;
      _pendingReason = 'resume';
      await rebuildSchedule(reason: r);
    }
  }

  Future<void> refreshDayInfo() async {
    final id = selected?.building.id;
    dayInfo = id == null ? null : await schedule.dayInfo(id, DateTime.now());
    _notify();
  }

  Future<void> refreshStatus() async {
    exactAllowed = await native.canScheduleExact();
    batteryIgnored = await native.isIgnoringBatteryOptimizations();
    audioRoute = await native.audioRoute();
    ringing = await native.isRinging();
    _notify();
  }

  Future<void> refreshRinging() async {
    final r = await native.isRinging();
    if (r != ringing) {
      ringing = r;
      _notify();
    }
  }

  Future<void> setAudioUsage(String usage) async {
    audioUsage = usage;
    await settings.set('audio_usage', usage);
    await logs.change('تغيير قناة الصوت إلى ${usage == 'media' ? 'الوسائط' : 'المنبّه'}');
    await rebuildSchedule(reason: 'change');
  }

  /// يجلب سجلات الجرس من الكود الأصلي ويخزنها في قاعدة البيانات.
  Future<void> syncNativeLogs() async {
    final entries = await native.pullLogs();
    if (entries.isNotEmpty) await logs.importNative(entries);
  }

  String soundAsset(String? soundId) {
    final s = sounds.where((e) => e.id == soundId);
    if (s.isNotEmpty) return s.first.assetPath;
    return sounds.isEmpty ? '' : sounds.first.assetPath;
  }

  /// تشغيل صوت الآن (جرس يدوي أو معاينة). لا يغيّر الجدول المحفوظ.
  Future<bool> playBell({
    required String soundId,
    required int durationSec,
    required double volume,
    bool manual = true,
    String label = 'جرس يدوي',
  }) async {
    if (ringing) return false;
    final ok = await native.playNow({
      'sound': soundAsset(soundId),
      'durationSec': durationSec,
      'volume': volume,
      'usage': audioUsage,
      'eventId': 0,
      'eventIds': <int>[],
      'buildingId': selected?.building.id ?? 0,
      'schoolName': selected?.schoolName ?? '',
      'buildingName': selected?.building.name ?? '',
      'label': label,
      'date': ymd(DateTime.now()),
    });
    if (ok) {
      ringing = true;
      _ringTimer?.cancel();
      _ringTimer = Timer(Duration(seconds: durationSec + 1), () {
        ringing = false;
        _notify();
      });
      _notify();
    }
    return ok;
  }

  Future<void> stopBell() async {
    await native.stop();
    _ringTimer?.cancel();
    ringing = false;
    _notify();
  }

  /// أقرب جرس قادم للمبنى المحدد.
  Map<String, dynamic>? nextAlarm([DateTime? now]) {
    final id = selected?.building.id;
    if (id == null) return null;
    final t = now ?? DateTime.now();
    for (final a in alarms) {
      if (a['buildingId'] != id) continue;
      final at = DateTime.tryParse((a['local'] as String).replaceFirst(' ', 'T'));
      if (at != null && at.isAfter(t)) return a;
    }
    return null;
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
    _midnight = Timer(next.difference(now), () async {
      await rebuildSchedule(reason: 'resume');
      await refreshDayInfo();
      _armMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    }
  }

  Future<void> _onResume() async {
    await refreshStatus();
    await syncNativeLogs();
    await rebuildSchedule(reason: 'resume');
    await refreshDayInfo();
    _armMidnight();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _midnight?.cancel();
    _ringTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// يعيد بناء الويدجت عند تغيّر الحالة.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// بدون الاشتراك في التغييرات.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

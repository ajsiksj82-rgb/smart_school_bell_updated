import 'dart:convert';

import 'package:flutter/services.dart';

/// الجسر إلى كود Android الأصلي (AlarmManager + خدمة تشغيل الصوت).
/// جميع الدوال آمنة: تعيد قيمة افتراضية عند الفشل ولا ترمي استثناءات.
class NativeBridge {
  static const MethodChannel _ch = MethodChannel('smart_school_bell/native');

  /// يرجع عدد المواعيد المجدولة فعليًا، أو -1 عند الفشل.
  Future<int> scheduleAlarms(List<Map<String, dynamic>> alarms) async {
    try {
      final n = await _ch.invokeMethod<int>('scheduleAlarms', jsonEncode(alarms));
      return n ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> cancelAll() => _bool('cancelAll');

  Future<bool> playNow(Map<String, dynamic> payload) async {
    try {
      return await _ch.invokeMethod<bool>('playNow', jsonEncode(payload)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stop() => _bool('stop');
  Future<bool> isRinging() => _bool('isRinging');
  Future<bool> canScheduleExact() => _bool('canScheduleExact', fallback: true);
  Future<bool> isIgnoringBatteryOptimizations() => _bool('isIgnoringBatteryOptimizations');
  Future<bool> openExactAlarmSettings() => _bool('openExactAlarmSettings');
  Future<bool> openBatterySettings() => _bool('openBatterySettings');
  Future<bool> openNotificationSettings() => _bool('openNotificationSettings');
  Future<bool> requestNotifications() => _bool('requestNotifications');

  /// wired | bluetooth | speaker | unknown (تقدير تقريبي فقط).
  Future<String> audioRoute() async {
    try {
      return await _ch.invokeMethod<String>('audioRoute') ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<List<dynamic>> pullLogs() async {
    try {
      final s = await _ch.invokeMethod<String>('pullLogs');
      if (s == null || s.isEmpty) return const [];
      final v = jsonDecode(s);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _bool(String m, {bool fallback = false}) async {
    try {
      return await _ch.invokeMethod<bool>(m) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

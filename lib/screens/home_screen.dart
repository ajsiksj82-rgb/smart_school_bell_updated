import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../app/app.dart' show kPrimary, kSecondary;
import '../app/app_state.dart';
import '../features/lesson_progress/services/lesson_progress_controller.dart';
import '../features/lesson_progress/widgets/day_timeline.dart';
import '../features/lesson_progress/widgets/lesson_progress_card.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/manual_bell_sheet.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'holidays_screen.dart';
import 'logs_screen.dart';
import 'schedule_hub_screen.dart';
import 'schools_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LessonProgressController? _controller;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _controller ??= LessonProgressController(app.dayProvider)..start();
    final id = app.selected?.building.id;
    if (id != null) _controller!.setBuilding(id);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _pickBuilding(AppState app) async {
    final refs = await app.schools.allBuildingRefs();
    if (!mounted) return;
    if (refs.isEmpty) {
      _push(const SchoolsScreen());
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(shrinkWrap: true, children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر المدرسة والمبنى', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final r in refs)
              ListTile(
                leading: Icon(r.building.id == app.selected?.building.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(r.title),
                subtitle: r.schoolActive ? null : const Text('المدرسة معطّلة: لا تُجدول أجراسها'),
                onTap: () => Navigator.pop(ctx, r.building.id),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) await app.selectBuilding(picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sel = app.selected;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجرس المدرسي الذكي', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: 'عن المطوّر',
              icon: const Icon(Icons.info_outline),
              onPressed: () => _push(const AboutScreen()),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildingCard(app, sel),
                  if (sel == null)
                    const AppCard(
                      accent: kSecondary,
                      padding: EdgeInsets.all(16),
                      child: Text('ابدأ بإضافة مدرسة ومبنى، ثم أنشئ جدول الأجراس من شاشة «الجدول».'),
                    )
                  else ...[
                    LessonProgressCard(controller: _controller!),
                    DayTimeline(controller: _controller!),
                    _nextBellCard(app),
                    _statusCard(app),
                    _bellButtons(app),
                  ],
                  const SizedBox(height: 8),
                  _shortcuts(app),
                  _developerFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildingCard(AppState app, BuildingRef? sel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kPrimary, Color(0xFF1B5FA8)],
        ),
        boxShadow: [
          BoxShadow(color: kPrimary.withAlpha(70), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _pickBuilding(app),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(sel?.title ?? 'لم يتم اختيار مدرسة',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.expand_more, color: Colors.white),
              ]),
              const SizedBox(height: 14),
              Ticking(
                builder: (c, now) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatClock(now),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(arabicDate(now),
                          style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 14)),
                    ),
                  ],
                ),
              ),
              if (app.dayInfo != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(app.dayInfo!.kind == 'normal' ? Icons.check_circle : Icons.event,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(app.dayInfo!.label,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nextBellCard(AppState app) {
    return AppCard(
      accent: Colors.amber.shade700,
      child: Ticking(
          builder: (c, now) {
            final a = app.nextAlarm(now);
            if (a == null) {
              return const Row(children: [
                Icon(Icons.notifications_off_outlined),
                SizedBox(width: 10),
                Expanded(child: Text('لا يوجد جرس مجدول قادم خلال الأيام القادمة')),
              ]);
            }
            final at = DateTime.parse((a['local'] as String).replaceFirst(' ', 'T'));
            final remaining = at.difference(now);
            final today = at.year == now.year && at.month == now.month && at.day == now.day;
            return Row(children: [
              const Icon(Icons.notifications_active_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الجرس التالي: ${a['label']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${today ? 'اليوم' : weekdayNames[at.weekday]} ${hm(at.hour * 60 + at.minute)}'),
                ]),
              ),
              Text(formatDuration(remaining),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]);
          },
        ),
    );
  }

  Widget _statusCard(AppState app) {
    final routeText = switch (app.audioRoute) {
      'wired' => 'متصل بمخرج سلكي (AUX/سماعة) - تقدير تقريبي',
      'bluetooth' => 'متصل ببلوتوث - تقدير تقريبي',
      'speaker' => 'سماعة الهاتف (لا يوجد مخرج خارجي)',
      _ => 'غير معروف',
    };
    final schedOk = app.scheduledCount > 0 && app.exactAllowed;
    return AppCard(
      accent: schedOk ? Colors.green.shade600 : Colors.orange.shade700,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _statusRow(
              schedOk ? Icons.check_circle : Icons.warning_amber_rounded,
              schedOk ? Colors.green.shade700 : Colors.orange.shade800,
              app.scheduledCount < 0
                  ? 'الجدولة: فشلت (راجع السجل والإعدادات)'
                  : app.scheduledCount == 0
                      ? 'الجدولة: لا توجد أجراس مجدولة'
                      : app.exactAllowed
                          ? 'الجدولة: ${app.scheduledCount} جرسًا مجدولًا (دقيقة)'
                          : 'الجدولة: ${app.scheduledCount} جرسًا لكن بدون صلاحية الدقة'),
          const SizedBox(height: 6),
          _statusRow(Icons.volume_up, Colors.blueGrey, 'الصوت: $routeText'),
          if (app.ringing) ...[
            const SizedBox(height: 6),
            _statusRow(Icons.graphic_eq, Colors.red.shade700, 'الجرس يعمل الآن'),
          ],
        ]),
    );
  }

  Widget _statusRow(IconData i, Color c, String t) => Row(children: [
        Icon(i, color: c, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(t)),
      ]);

  Widget _bellButtons(AppState app) {
    return Column(children: [
      SizedBox(
        height: 72,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
          ),
          icon: const Icon(Icons.notifications_active, size: 32),
          label: const Text('تشغيل الجرس',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          onPressed: () {
            final now = DateTime.now();
            if (now.difference(_lastTap) < const Duration(seconds: 3)) return; // منع الضغط المتكرر
            _lastTap = now;
            if (app.ringing) {
              showMsg(context, 'يوجد رنين جارٍ. أوقفه أولًا.', error: true);
              return;
            }
            showManualBellSheet(context);
          },
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('إيقاف الرنين الحالي', style: TextStyle(fontSize: 18)),
          onPressed: () async {
            await app.stopBell();
            if (mounted) showMsg(context, 'تم إرسال أمر الإيقاف');
          },
        ),
      ),
    ]);
  }

  Widget _shortcuts(AppState app) {
    final sel = app.selected;
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.schedule, 'الجدول', const Color(0xFF1565C0), () {
        if (sel == null) {
          showMsg(context, 'اختر مبنى أولًا', error: true);
        } else {
          _push(ScheduleHubScreen(building: sel.building, schoolName: sel.schoolName));
        }
      }),
      (Icons.library_music, 'الأصوات', const Color(0xFF6A1B9A), () => _push(const SoundsScreen())),
      (Icons.beach_access, 'الإجازات', const Color(0xFFEF6C00), () => _push(const HolidaysScreen())),
      (Icons.business, 'المدارس', const Color(0xFF00796B), () => _push(const SchoolsScreen())),
      (Icons.history, 'السجل', const Color(0xFF546E7A), () => _push(const LogsScreen())),
      (Icons.backup, 'النسخ الاحتياطي', const Color(0xFF2E7D32), () => _push(const BackupScreen())),
      (Icons.settings, 'الإعدادات', const Color(0xFF455A64), () => _push(const SettingsScreen())),
      (Icons.person, 'عن المطوّر', const Color(0xFFC2185B), () => _push(const AboutScreen())),
    ];
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      const cols = 4;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                onTap: it.$4,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: it.$3.withAlpha(28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(it.$1, size: 24, color: it.$3),
                  ),
                  const SizedBox(height: 6),
                  Text(it.$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      );
    });
  }

  Widget _developerFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _push(const AboutScreen()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Text('تطوير: $kDeveloperName',
                style: TextStyle(
                    color: Colors.blueGrey.shade700, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('📞 $kDeveloperPhone',
                  style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

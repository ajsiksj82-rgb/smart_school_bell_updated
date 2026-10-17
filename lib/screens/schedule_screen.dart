import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../features/lesson_progress/models/lesson_progress_models.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.building, required this.schoolName});
  final Building building;
  final String schoolName;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _weekday = DateTime.now().weekday;
  ScheduleDay? _day;
  List<BellEvent> _events = [];
  bool _loading = true;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _load();
    }
  }

  AppState get _app => AppScope.read(context);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _app.schedule.day(widget.building.id!, _weekday);
      final ev = await _app.schedule.events(d.id!);
      if (mounted) {
        setState(() {
          _day = d;
          _events = ev;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(context, 'تعذر تحميل الجدول: $e', error: true);
      }
    }
  }

  Future<void> _editEvent([BellEvent? e]) async {
    final result = await showDialog<BellEvent>(
      context: context,
      builder: (_) => _EventDialog(initial: e, scheduleId: _day!.id, building: widget.building),
    );
    if (result == null) return;
    final err = await _app.schedule.saveEvent(result);
    if (!mounted) return;
    if (err != null) {
      showMsg(context, err, error: true);
    }
    await _load();
  }

  Future<void> _copyDay() async {
    final selected = <int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('نسخ جدول ${weekdayNames[_weekday]} إلى:'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final wd in weekdayOrder.where((w) => w != _weekday))
                  CheckboxListTile(
                    title: Text(weekdayNames[wd]!),
                    value: selected.contains(wd),
                    onChanged: (v) => setS(() => v == true ? selected.add(wd) : selected.remove(wd)),
                  ),
                const Text('سيُستبدل جدول الأيام المحددة بالكامل.', style: TextStyle(fontSize: 12)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نسخ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    final ids = <int>[];
    for (final wd in selected) {
      ids.add((await _app.schedule.day(widget.building.id!, wd)).id);
    }
    await _app.schedule.copyDay(_day!.id, ids);
    if (mounted) showMsg(context, 'تم نسخ الجدول');
  }

  Future<void> _quickGenerate() async {
    int start = 7 * 60;
    final lessons = TextEditingController(text: '7');
    final lessonMin = TextEditingController(text: '45');
    final breakAfter = TextEditingController(text: '3');
    final breakMin = TextEditingController(text: '20');
    final assembly = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('إنشاء جدول اليوم تلقائيًا'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('بداية الدوام'),
                  trailing: Text(hm(start), style: const TextStyle(fontSize: 20)),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60));
                    if (t != null) setS(() => start = t.hour * 60 + t.minute);
                  },
                ),
                _num(assembly, 'مدة الطابور الصباحي بالدقائق (0 = بدون)'),
                _num(lessons, 'عدد الحصص'),
                _num(lessonMin, 'مدة الحصة بالدقائق'),
                _num(breakAfter, 'الاستراحة بعد الحصة رقم (0 = بدون)'),
                _num(breakMin, 'مدة الاستراحة بالدقائق'),
                const SizedBox(height: 8),
                const Text('سيتم استبدال أحداث هذا اليوم الحالية.', style: TextStyle(fontSize: 12)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    int n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final err = await _app.schedule.quickGenerate(
      scheduleId: _day!.id,
      startMinute: start,
      lessons: n(lessons),
      lessonMinutes: n(lessonMin),
      breakAfterLesson: n(breakAfter),
      breakMinutes: n(breakMin),
      assemblyMinutes: n(assembly),
      soundId: widget.building.defaultSound,
    );
    if (!mounted) return;
    if (err != null) showMsg(context, err, error: true);
    await _load();
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('جدول ${widget.building.name}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) => v == 'copy' ? _copyDay() : _quickGenerate(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'gen', child: Text('إنشاء جدول تلقائي')),
                PopupMenuItem(value: 'copy', child: Text('نسخ اليوم إلى أيام أخرى')),
              ],
            ),
          ],
        ),
        floatingActionButton: _day == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _editEvent(), icon: const Icon(Icons.add_alarm), label: const Text('حدث جرس')),
        body: Column(children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (final wd in weekdayOrder)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(weekdayNames[wd]!),
                      selected: wd == _weekday,
                      onSelected: (_) {
                        _weekday = wd;
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_day != null)
            SwitchListTile(
              title: const Text('يوم دوام'),
              subtitle: Text(_day!.isWorking ? 'ستُجدول أجراس هذا اليوم' : 'عطلة أسبوعية: لا أجراس'),
              value: _day!.isWorking,
              onChanged: (v) async {
                await app.schedule.setWorking(_day!.id, v);
                await _load();
              },
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const EmptyState(
                        icon: Icons.alarm_off,
                        text: 'لا توجد أحداث في هذا اليوم.\nأضف حدثًا أو استخدم «إنشاء جدول تلقائي» من القائمة.')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                        children: [
                          for (final e in _events)
                            Card(
                              child: ListTile(
                                leading: Text(hm(e.minute),
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                title: Text(bellTypeLabel(e.type)),
                                subtitle: Text([
                                  if (e.label != null) e.label!,
                                  if (e.subject != null) e.subject!,
                                  '${e.durationSec} ث',
                                ].join(' • ')),
                                onTap: () => _editEvent(e),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Switch(
                                    value: e.enabled,
                                    onChanged: (v) async {
                                      await app.schedule.setEnabled(e, v);
                                      await _load();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final ok = await confirmDialog(context,
                                          title: 'حذف الحدث؟',
                                          message: '${bellTypeLabel(e.type)} ${hm(e.minute)}',
                                          confirmText: 'حذف',
                                          danger: true);
                                      if (ok) {
                                        await app.schedule.deleteEvent(e);
                                        await _load();
                                      }
                                    },
                                  ),
                                ]),
                              ),
                            ),
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({required this.initial, required this.scheduleId, required this.building});
  final BellEvent? initial;
  final int scheduleId;
  final Building building;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late BellEventType _type;
  late int _minute;
  late TextEditingController _label;
  late TextEditingController _subject;
  late TextEditingController _duration;
  String? _sound;
  bool _enabled = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _type = e?.type ?? BellEventType.lessonStart;
    _minute = e?.minute ?? 8 * 60;
    _label = TextEditingController(text: e?.label ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _duration = TextEditingController(text: '${e?.durationSec ?? 5}');
    _sound = e?.soundId ?? widget.building.defaultSound;
    _enabled = e?.enabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة حدث جرس' : 'تعديل حدث جرس'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<BellEventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع الحدث'),
              items: [for (final t in BellEventType.values) DropdownMenuItem(value: t, child: Text(bellTypeLabel(t)))],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('وقت الرنين'),
              trailing: Text(hm(_minute), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              onTap: () async {
                final t = await showTimePicker(
                    context: context, initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60));
                if (t != null) setState(() => _minute = t.hour * 60 + t.minute);
              },
            ),
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'اسم مخصص (اختياري)')),
            if (_type == BellEventType.lessonStart)
              TextField(controller: _subject, decoration: const InputDecoration(labelText: 'المادة (اختياري)')),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدة الرنين بالثواني (1-300)'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: app.sounds.any((s) => s.id == _sound) ? _sound : null,
                  decoration: const InputDecoration(labelText: 'الصوت'),
                  items: [for (final s in app.sounds) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => setState(() => _sound = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill),
                tooltip: 'معاينة',
                onPressed: () async {
                  final d = (int.tryParse(_duration.text.trim()) ?? 3).clamp(1, 5);
                  final ok = await app.playBell(
                      soundId: _sound ?? 'bell_classic',
                      durationSec: d,
                      volume: widget.building.volume,
                      label: 'معاينة صوت');
                  if (!ok && context.mounted) showMsg(context, 'تعذرت المعاينة', error: true);
                },
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مفعّل'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final d = int.tryParse(_duration.text.trim());
              if (d == null || d < 1 || d > 300) {
                setState(() => _error = 'مدة الرنين يجب أن تكون رقمًا بين 1 و300');
                return;
              }
              Navigator.pop(
                context,
                BellEvent(
                  id: widget.initial?.id,
                  scheduleId: widget.scheduleId,
                  type: _type,
                  minute: _minute,
                  label: _label.text,
                  subject: _type == BellEventType.lessonStart ? _subject.text : null,
                  soundId: _sound,
                  durationSec: d,
                  enabled: _enabled,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

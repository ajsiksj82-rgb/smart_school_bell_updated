import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import 'manual_schedule_screens.dart';
import 'schedule_screen.dart';

/// نقطة الدخول لضبط جدول الحصص: ضبط يدوي أو ضبط تلقائي.
class ScheduleHubScreen extends StatelessWidget {
  const ScheduleHubScreen({super.key, required this.building, required this.schoolName});
  final Building building;
  final String schoolName;

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(sub),
                ]),
              ),
              const Icon(Icons.chevron_left),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('جدول الحصص - ${building.name}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(schoolName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _tile(
            context,
            Icons.touch_app,
            'الضبط اليدوي',
            'اختر اليوم، ثم الطابور أو الحصة، وحدّد زمنها (من - إلى).',
            ManualDaysScreen(building: building, schoolName: schoolName),
          ),
          _tile(
            context,
            Icons.auto_fix_high,
            'الضبط التلقائي',
            'أدخل بداية الدوام وعدد الحصص ومدتها، وتُنشأ كل الأوقات تلقائيًا للأيام التي تختارها.',
            AutoSetupScreen(building: building),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('عرض كل الأحداث وإعدادات متقدمة'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ScheduleScreen(building: building, schoolName: schoolName))),
          ),
        ]),
      ),
    );
  }
}

class AutoSetupScreen extends StatefulWidget {
  const AutoSetupScreen({super.key, required this.building});
  final Building building;

  @override
  State<AutoSetupScreen> createState() => _AutoSetupScreenState();
}

class _AutoSetupScreenState extends State<AutoSetupScreen> {
  int _start = 7 * 60;
  final _assembly = TextEditingController(text: '10');
  final _lessons = TextEditingController(text: '5');
  final _lessonMin = TextEditingController(text: '45');
  final _breakAfter = TextEditingController(text: '3');
  final _breakMin = TextEditingController(text: '20');
  final Map<int, int> _scheduleIds = {}; // weekday -> schedule id
  final Set<int> _selected = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    for (final wd in weekdayOrder) {
      final d = await app.schedule.day(widget.building.id!, wd);
      _scheduleIds[wd] = d.id;
      if (d.isWorking) _selected.add(wd);
    }
    if (mounted) setState(() {});
  }

  int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  String _summary() {
    final lessons = _n(_lessons);
    final b = _n(_breakAfter) > 0 ? _n(_breakMin) : 0;
    final end = _start + _n(_assembly) + lessons * _n(_lessonMin) + b;
    if (end > 1439) return 'الجدول يتجاوز منتصف الليل';
    return 'ينتهي الدوام عند ${hm(end)}';
  }

  Future<void> _apply() async {
    final app = AppScope.read(context);
    final ok = await confirmDialog(context,
        title: 'تفعيل الضبط التلقائي؟',
        message: 'ستُستبدل أحداث ${_selected.length} يوم/أيام بالجدول المحسوب تلقائيًا، '
            'وتُفعَّل هذه الأيام كأيام دوام. يمكنك بعدها تعديل أي حصة يدويًا.',
        confirmText: 'تفعيل');
    if (!ok) return;
    setState(() => _busy = true);
    final err = await app.schedule.quickGenerateDays(
      scheduleIds: [for (final wd in _selected) _scheduleIds[wd]!],
      startMinute: _start,
      lessons: _n(_lessons),
      lessonMinutes: _n(_lessonMin),
      breakAfterLesson: _n(_breakAfter),
      breakMinutes: _n(_breakMin),
      assemblyMinutes: _n(_assembly),
      soundId: widget.building.defaultSound,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showMsg(context, err, error: true);
    } else {
      showMsg(context, 'تم إنشاء الجدول تلقائيًا');
      Navigator.of(context).pop();
    }
  }

  Widget _num(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الضبط التلقائي')),
        body: !_loaded || _scheduleIds.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('الأيام المطلوب ضبطها', style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  for (final wd in weekdayOrder)
                    FilterChip(
                      label: Text(weekdayNames[wd]!),
                      selected: _selected.contains(wd),
                      onSelected: (v) => setState(() => v ? _selected.add(wd) : _selected.remove(wd)),
                    ),
                ]),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('بداية الدوام'),
                    trailing: Text(hm(_start), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60));
                      if (t != null) setState(() => _start = t.hour * 60 + t.minute);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _num(_assembly, 'مدة الطابور الصباحي بالدقائق (0 = بدون طابور)'),
                _num(_lessons, 'عدد الحصص'),
                _num(_lessonMin, 'مدة الحصة بالدقائق'),
                _num(_breakAfter, 'الاستراحة بعد الحصة رقم (0 = بدون استراحة)'),
                _num(_breakMin, 'مدة الاستراحة بالدقائق'),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(padding: const EdgeInsets.all(14), child: Text(_summary())),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('تفعيل الضبط التلقائي', style: TextStyle(fontSize: 18)),
                    onPressed: (_busy || _selected.isEmpty) ? null : _apply,
                  ),
                ),
              ]),
      ),
    );
  }
}

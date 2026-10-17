import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../repositories/slot_logic.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

/// النافذة 1: أيام الأسبوع.
class ManualDaysScreen extends StatefulWidget {
  const ManualDaysScreen({super.key, required this.building, required this.schoolName});
  final Building building;
  final String schoolName;

  @override
  State<ManualDaysScreen> createState() => _ManualDaysScreenState();
}

class _DayRow {
  _DayRow(this.weekday, this.working, this.lessons);
  final int weekday;
  final bool working;
  final int lessons;
}

class _ManualDaysScreenState extends State<ManualDaysScreen> {
  List<_DayRow>? _rows;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _load();
    }
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final rows = <_DayRow>[];
    for (final wd in weekdayOrder) {
      final d = await app.schedule.day(widget.building.id!, wd);
      final slots = SlotLogic.build(await app.schedule.events(d.id), minLessons: 0);
      rows.add(_DayRow(wd, d.isWorking, slots.where((s) => s.kind == SlotKind.lesson && s.isSet).length));
    }
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الضبط اليدوي - اختر اليوم')),
        body: _rows == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final r in _rows!)
                  Card(
                    child: ListTile(
                      minVerticalPadding: 16,
                      leading: Icon(r.working ? Icons.event_available : Icons.event_busy,
                          color: r.working ? null : Colors.grey),
                      title: Text(weekdayNames[r.weekday]!, style: const TextStyle(fontSize: 20)),
                      subtitle: Text(r.working
                          ? (r.lessons == 0 ? 'يوم دوام • لم تُضبط حصص' : 'يوم دوام • ${r.lessons} حصص مضبوطة')
                          : 'عطلة أسبوعية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ManualSlotsScreen(building: widget.building, weekday: r.weekday)));
                        _load();
                      },
                    ),
                  ),
              ]),
      ),
    );
  }
}

/// النافذة 2: الطابور والحصص والاستراحات لليوم المحدد.
class ManualSlotsScreen extends StatefulWidget {
  const ManualSlotsScreen({super.key, required this.building, required this.weekday});
  final Building building;
  final int weekday;

  @override
  State<ManualSlotsScreen> createState() => _ManualSlotsScreenState();
}

class _ManualSlotsScreenState extends State<ManualSlotsScreen> {
  ScheduleDay? _day;
  List<SlotInfo> _slots = [];
  int _minLessons = 5;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _load();
    }
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final d = await app.schedule.day(widget.building.id!, widget.weekday);
    final slots = SlotLogic.build(await app.schedule.events(d.id), minLessons: _minLessons);
    if (mounted) {
      setState(() {
        _day = d;
        _slots = slots;
      });
    }
  }

  Future<void> _open(SlotInfo s) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SlotEditScreen(building: widget.building, scheduleId: _day!.id, slot: s, all: _slots)));
    if (changed == true) await _load();
  }

  Widget _slotTile(SlotInfo s) => Card(
        child: ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: s.isSet ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            foregroundColor: s.isSet ? Colors.white : Colors.black54,
            child: s.kind == SlotKind.assembly
                ? const Icon(Icons.flag, size: 20)
                : s.kind == SlotKind.breakTime
                    ? const Icon(Icons.free_breakfast, size: 20)
                    : Text('${s.number}'),
          ),
          title: Text(s.name, style: const TextStyle(fontSize: 18)),
          subtitle: Text(s.rangeText),
          trailing: Icon(s.isSet ? Icons.check_circle : Icons.edit_outlined,
              color: s.isSet ? Colors.green.shade700 : null),
          onTap: () => _open(s),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final lessons = _slots.where((s) => s.kind == SlotKind.lesson).toList();
    final breaks = _slots.where((s) => s.kind == SlotKind.breakTime).toList();
    final assembly = _slots.where((s) => s.kind == SlotKind.assembly).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(weekdayNames[widget.weekday]!)),
        body: _day == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(12), children: [
                SwitchListTile(
                  title: const Text('يوم دوام'),
                  subtitle: Text(_day!.isWorking ? 'ستُجدول أجراس هذا اليوم' : 'عطلة: لا تُجدول أجراس'),
                  value: _day!.isWorking,
                  onChanged: (v) async {
                    await app.schedule.setWorking(_day!.id, v);
                    await _load();
                  },
                ),
                for (final s in assembly) _slotTile(s),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text('الحصص', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final s in lessons) _slotTile(s),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حصة'),
                  onPressed: () {
                    _minLessons = lessons.length + 1;
                    _load();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                  child: Text('الاستراحات', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final s in breaks) _slotTile(s),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة استراحة'),
                  onPressed: () => _open(SlotInfo(kind: SlotKind.breakTime, number: breaks.length + 1)),
                ),
                const SizedBox(height: 24),
              ]),
      ),
    );
  }
}

/// النافذة 3: زمن الخانة (من - إلى) وإعدادات الرنين.
class SlotEditScreen extends StatefulWidget {
  const SlotEditScreen({
    super.key,
    required this.building,
    required this.scheduleId,
    required this.slot,
    required this.all,
  });
  final Building building;
  final int scheduleId;
  final SlotInfo slot;
  final List<SlotInfo> all;

  @override
  State<SlotEditScreen> createState() => _SlotEditScreenState();
}

class _SlotEditScreenState extends State<SlotEditScreen> {
  late int _from;
  late int _to;
  late TextEditingController _subject;
  late TextEditingController _duration;
  String? _sound;
  bool _enabled = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.slot;
    if (s.isSet) {
      _from = s.from!;
      _to = s.to!;
    } else {
      final prev = widget.all
          .where((x) => x.isSet && x.kind == s.kind && x.number < s.number)
          .fold<int?>(null, (m, x) => m == null || x.to! > m ? x.to : m);
      final asm = widget.all.where((x) => x.kind == SlotKind.assembly && x.isSet).firstOrNull;
      _from = switch (s.kind) {
        SlotKind.assembly => 7 * 60 + 30,
        SlotKind.lesson => prev ?? asm?.to ?? 8 * 60,
        SlotKind.breakTime => 10 * 60,
      };
      final len = switch (s.kind) {
        SlotKind.assembly => 10,
        SlotKind.lesson => 45,
        SlotKind.breakTime => 20,
      };
      _to = (_from + len).clamp(0, 1439);
    }
    _subject = TextEditingController(text: s.start?.subject ?? '');
    _duration = TextEditingController(text: '${s.start?.durationSec ?? 5}');
    _sound = s.start?.soundId ?? widget.building.defaultSound;
    _enabled = s.start?.enabled ?? true;
  }

  Future<void> _pick(bool isFrom) async {
    final cur = isFrom ? _from : _to;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (isFrom) {
        final len = _to - _from;
        _from = m;
        if (len > 0 && !widget.slot.isSet) _to = (m + len).clamp(0, 1439);
      } else {
        _to = m;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final d = int.tryParse(_duration.text.trim());
    if (d == null || d < 1 || d > 300) {
      setState(() => _error = 'مدة الرنين يجب أن تكون رقمًا بين 1 و300 ثانية');
      return;
    }
    setState(() => _busy = true);
    final err = await AppScope.read(context).schedule.saveSlot(
          scheduleId: widget.scheduleId,
          kind: widget.slot.kind,
          number: widget.slot.number,
          from: _from,
          to: _to,
          subject: _subject.text,
          soundId: _sound,
          durationSec: d,
          enabled: _enabled,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      showMsg(context, 'تم حفظ ${widget.slot.name}');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'حذف أوقات ${widget.slot.name}؟',
        message: widget.slot.kind == SlotKind.assembly
            ? 'ستُحذف أوقات الطابور.'
            : 'ستُحذف أوقات هذه الخانة، وقد تتغير أرقام الخانات التالية لأن الترقيم يتبع ترتيب الزمن.',
        confirmText: 'حذف',
        danger: true);
    if (!ok) return;
    await AppScope.read(context).schedule.deleteSlot(widget.slot);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _timeTile(String label, int value, bool isFrom) => Card(
        child: ListTile(
          minVerticalPadding: 14,
          title: Text(label, style: const TextStyle(fontSize: 18)),
          trailing: Text(hm(value), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          onTap: () => _pick(isFrom),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final mins = _to - _from;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.slot.name)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _timeTile('من', _from, true),
          _timeTile('إلى', _to, false),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(mins > 0 ? 'المدة: $mins دقيقة' : 'وقت النهاية يجب أن يكون بعد البداية',
                style: TextStyle(color: mins > 0 ? null : Colors.red)),
          ),
          if (widget.slot.kind == SlotKind.lesson)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'المادة (اختياري)', border: OutlineInputBorder()),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: app.sounds.any((s) => s.id == _sound) ? _sound : null,
                decoration: const InputDecoration(labelText: 'صوت الجرس', border: OutlineInputBorder()),
                items: [for (final s in app.sounds) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setState(() => _sound = v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_fill, size: 32),
              tooltip: 'معاينة',
              onPressed: () async {
                final ok = await app.playBell(
                    soundId: _sound ?? 'bell_classic',
                    durationSec: (int.tryParse(_duration.text.trim()) ?? 3).clamp(1, 5),
                    volume: widget.building.volume,
                    label: 'معاينة صوت');
                if (!ok && context.mounted) showMsg(context, 'تعذرت المعاينة', error: true);
              },
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مدة الرنين بالثواني', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            title: const Text('مفعّلة (يرنّ الجرس في بدايتها ونهايتها)'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Colors.red.shade900))),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ', style: TextStyle(fontSize: 18)),
              onPressed: _busy ? null : _save,
            ),
          ),
          if (widget.slot.start != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف هذه الخانة'),
              onPressed: _busy ? null : _delete,
            ),
          ],
        ]),
      ),
    );
  }
}

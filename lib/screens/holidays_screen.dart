import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  List<Holiday>? _list;
  List<Building> _buildings = [];
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
    final sel = app.selected;
    if (sel == null) {
      if (mounted) setState(() => _list = []);
      return;
    }
    final l = await app.holidays.forSchool(sel.building.schoolId);
    final b = await app.schools.buildings(sel.building.schoolId);
    if (mounted) {
      setState(() {
        _list = l;
        _buildings = b;
      });
    }
  }

  Future<void> _edit([Holiday? h]) async {
    final sel = AppScope.read(context).selected!;
    final result = await showDialog<Holiday>(
      context: context,
      builder: (_) => _HolidayDialog(initial: h, schoolId: sel.building.schoolId, buildings: _buildings),
    );
    if (result == null) return;
    final err = await AppScope.read(context).holidays.save(result);
    if (!mounted) return;
    if (err != null) showMsg(context, err, error: true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sel = app.selected;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(sel == null ? 'الإجازات' : 'إجازات ${sel.schoolName}')),
        floatingActionButton: sel == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إجازة')),
        body: sel == null
            ? const EmptyState(icon: Icons.school_outlined, text: 'اختر مدرسة ومبنى أولًا')
            : _list == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'العطلة الأسبوعية (مثل الجمعة والسبت) تُحدَّد من شاشة الجدول بتعطيل «يوم دوام». '
                            'الإجازات هنا تعطّل الجرس تلقائيًا في نطاقها، و«يوم دوام استثنائي» يلغي التعطيل لليوم المحدد.',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    if (_list!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('لا توجد إجازات مسجلة')),
                      ),
                    for (final h in _list!)
                      Card(
                        child: ListTile(
                          leading: Icon(h.kind == 'override' ? Icons.work : Icons.beach_access,
                              color: h.active ? null : Colors.grey),
                          title: Text(h.title),
                          subtitle: Text([
                            holidayKindLabels[h.kind] ?? h.kind,
                            ymd(h.start) == ymd(h.end) ? ymd(h.start) : '${ymd(h.start)} → ${ymd(h.end)}',
                            h.buildingId == null
                                ? 'كل المدرسة'
                                : (_buildings.where((b) => b.id == h.buildingId).map((b) => b.name).firstOrNull ?? 'مبنى'),
                            if (h.notes != null) h.notes!,
                          ].join(' • ')),
                          onTap: () => _edit(h),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Switch(
                                value: h.active,
                                onChanged: (v) async {
                                  await app.holidays.setActive(h, v);
                                  await _load();
                                }),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirmDialog(context,
                                    title: 'حذف الإجازة؟', message: h.title, confirmText: 'حذف', danger: true);
                                if (ok) {
                                  await app.holidays.delete(h);
                                  await _load();
                                }
                              },
                            ),
                          ]),
                        ),
                      ),
                  ]),
      ),
    );
  }
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({required this.initial, required this.schoolId, required this.buildings});
  final Holiday? initial;
  final int schoolId;
  final List<Building> buildings;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  late TextEditingController _title;
  late TextEditingController _notes;
  late String _kind;
  late DateTime _start;
  late DateTime _end;
  int? _buildingId;
  bool _active = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.initial;
    final today = DateTime.now();
    _title = TextEditingController(text: h?.title ?? '');
    _notes = TextEditingController(text: h?.notes ?? '');
    _kind = h?.kind ?? 'official';
    _start = h?.start ?? DateTime(today.year, today.month, today.day);
    _end = h?.end ?? _start;
    _buildingId = h?.buildingId;
    _active = h?.active ?? true;
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة إجازة' : 'تعديل إجازة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'اسم الإجازة')),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: [for (final e in holidayKindLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('من'),
              trailing: Text(ymd(_start)),
              onTap: () async {
                final d = await _pick(_start);
                if (d != null) {
                  setState(() {
                    _start = d;
                    if (_end.isBefore(_start)) _end = _start;
                  });
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إلى'),
              trailing: Text(ymd(_end)),
              onTap: () async {
                final d = await _pick(_end);
                if (d != null) setState(() => _end = d);
              },
            ),
            DropdownButtonFormField<int?>(
              initialValue: _buildingId,
              decoration: const InputDecoration(labelText: 'النطاق'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('كل المدرسة')),
                for (final b in widget.buildings) DropdownMenuItem<int?>(value: b.id, child: Text('مبنى: ${b.name}')),
              ],
              onChanged: (v) => setState(() => _buildingId = v),
            ),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مفعّلة'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (_title.text.trim().isEmpty) {
                setState(() => _error = 'اكتب اسم الإجازة');
                return;
              }
              if (_end.isBefore(_start)) {
                setState(() => _error = 'تاريخ النهاية قبل البداية');
                return;
              }
              Navigator.pop(
                context,
                Holiday(
                  id: widget.initial?.id,
                  schoolId: widget.schoolId,
                  buildingId: _buildingId,
                  title: _title.text,
                  kind: _kind,
                  notes: _notes.text,
                  start: _start,
                  end: _end,
                  active: _active,
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

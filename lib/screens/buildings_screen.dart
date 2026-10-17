import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'schedule_hub_screen.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key, required this.school});
  final School school;

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<Building>? _list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_list == null) _load();
  }

  Future<void> _load() async {
    final l = await AppScope.read(context).schools.buildings(widget.school.id!);
    if (mounted) setState(() => _list = l);
  }

  Future<void> _edit([Building? b]) async {
    final app = AppScope.read(context);
    final name = TextEditingController(text: b?.name ?? '');
    var volume = b?.volume ?? 1.0;
    String? sound = b?.defaultSound ?? (app.sounds.isEmpty ? null : app.sounds.first.id);
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(b == null ? 'إضافة مبنى' : 'تعديل مبنى'),
            content: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المبنى'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اسم المبنى' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: app.sounds.any((s) => s.id == sound) ? sound : null,
                    decoration: const InputDecoration(labelText: 'الصوت الافتراضي'),
                    items: [for (final s in app.sounds) DropdownMenuItem(value: s.id, child: Text(s.name))],
                    onChanged: (v) => setS(() => sound = v),
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: Text('مستوى الصوت: ${(volume * 100).round()}%')),
                  Slider(value: volume, min: 0, max: 1, divisions: 20, onChanged: (v) => setS(() => volume = v)),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () {
                    if (key.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final nb = Building(
          id: b?.id, schoolId: widget.school.id!, name: name.text, volume: volume, defaultSound: sound);
      if (b == null) {
        await app.schools.addBuilding(nb);
      } else {
        await app.schools.updateBuilding(nb);
      }
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, 'تعذر الحفظ: $e', error: true);
    }
  }

  Future<void> _delete(Building b) async {
    final app = AppScope.read(context);
    final impact = await app.schools.buildingImpact(b.id!);
    if (!mounted) return;
    final ok = await confirmDialog(context,
        title: 'حذف المبنى «${b.name}»؟',
        message: 'سيُحذف جدوله بالكامل (${impact['events']} حدث جرس) وإجازاته الخاصة (${impact['holidays']}). لا يمكن التراجع.',
        confirmText: 'حذف نهائي',
        danger: true);
    if (!ok) return;
    try {
      await app.schools.deleteBuilding(b.id!, b.name);
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, 'تعذر الحذف: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('مباني ${widget.school.name}')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('مبنى')),
        body: _list == null
            ? const Center(child: CircularProgressIndicator())
            : _list!.isEmpty
                ? const EmptyState(icon: Icons.apartment, text: 'لا توجد مبانٍ لهذه المدرسة.\nأضف مبنى لإنشاء جدول له.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    children: [
                      for (final b in _list!)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.apartment),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(b.name,
                                        style: Theme.of(context).textTheme.titleMedium)),
                                if (app.selected?.building.id == b.id)
                                  const Chip(label: Text('النشط')),
                                PopupMenuButton<String>(
                                  onSelected: (v) => v == 'edit' ? _edit(b) : _delete(b),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                                  ],
                                ),
                              ]),
                              Text('مستوى الصوت: ${(b.volume * 100).round()}%'),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('اختيار كمبنى نشط'),
                                  onPressed: () async {
                                    await app.selectBuilding(b.id!);
                                    if (mounted) showMsg(context, 'تم اختيار ${b.name}');
                                  },
                                ),
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.schedule),
                                  label: const Text('الجدول'),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          ScheduleHubScreen(building: b, schoolName: widget.school.name))),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

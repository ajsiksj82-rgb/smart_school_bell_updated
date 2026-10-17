import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'buildings_screen.dart';

class SchoolsScreen extends StatefulWidget {
  const SchoolsScreen({super.key});

  @override
  State<SchoolsScreen> createState() => _SchoolsScreenState();
}

class _SchoolsScreenState extends State<SchoolsScreen> {
  List<School>? _schools;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_schools == null) _load();
  }

  Future<void> _load() async {
    try {
      final s = await AppScope.read(context).schools.schools();
      if (mounted) setState(() => _schools = s);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل المدارس: $e');
    }
  }

  Future<void> _edit([School? s]) async {
    final app = AppScope.read(context);
    final name = TextEditingController(text: s?.name ?? '');
    final addr = TextEditingController(text: s?.address ?? '');
    var active = s?.isActive ?? true;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(s == null ? 'إضافة مدرسة' : 'تعديل مدرسة'),
            content: Form(
              key: key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المدرسة'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اسم المدرسة' : null,
                ),
                TextFormField(controller: addr, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مفعّلة (تُجدول أجراسها)'),
                  value: active,
                  onChanged: (v) => setS(() => active = v),
                ),
              ]),
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
      final school = School(id: s?.id, name: name.text, address: addr.text, isActive: active);
      if (s == null) {
        final id = await app.schools.addSchool(school);
        if (mounted) {
          showMsg(context, 'تمت إضافة المدرسة. أضف مبنى لها الآن.');
          await _load();
          final added = (await app.schools.schools()).firstWhere((x) => x.id == id);
          if (mounted) {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuildingsScreen(school: added)));
          }
        }
      } else {
        await app.schools.updateSchool(school);
      }
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, 'تعذر الحفظ: $e', error: true);
    }
  }

  Future<void> _delete(School s) async {
    final app = AppScope.read(context);
    final impact = await app.schools.schoolImpact(s.id!);
    if (!mounted) return;
    final ok = await confirmDialog(context,
        title: 'حذف المدرسة «${s.name}»؟',
        message: 'سيُحذف نهائيًا: ${impact['buildings']} مبنى، ${impact['events']} حدث جرس، '
            '${impact['holidays']} إجازة. لا يمكن التراجع.',
        confirmText: 'حذف نهائي',
        danger: true);
    if (!ok) return;
    try {
      await app.schools.deleteSchool(s.id!, s.name);
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
        appBar: AppBar(title: const Text('المدارس والمباني')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('مدرسة')),
        body: _error != null
            ? EmptyState(icon: Icons.error_outline, text: _error!)
            : _schools == null
                ? const Center(child: CircularProgressIndicator())
                : _schools!.isEmpty
                    ? const EmptyState(icon: Icons.school_outlined, text: 'لا توجد مدارس بعد.\nاضغط «مدرسة» للإضافة.')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                        children: [
                          for (final s in _schools!)
                            Card(
                              child: ListTile(
                                leading: Icon(Icons.school,
                                    color: s.isActive ? null : Colors.grey),
                                title: Text(s.name),
                                subtitle: Text([
                                  if (s.address != null) s.address!,
                                  if (!s.isActive) 'معطّلة',
                                  if (app.selected?.building.schoolId == s.id) 'المدرسة النشطة',
                                ].join(' • ')),
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => BuildingsScreen(school: s)))
                                    .then((_) => _load()),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) => v == 'edit' ? _edit(s) : _delete(s),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}

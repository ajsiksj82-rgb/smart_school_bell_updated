import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry>? _list;
  DateTime? _day;
  String? _kind;
  bool _init = false;

  static const _kinds = {
    null: 'الكل',
    'bell': 'الأجراس',
    'schedule': 'الجدولة',
    'change': 'التغييرات',
    'error': 'الأخطاء',
  };

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
    await app.syncNativeLogs();
    final l = await app.logs.query(day: _day, kind: _kind);
    if (mounted) setState(() => _list = l);
  }

  Color _color(LogEntry e) {
    if (e.result == 'error' || e.kind == 'error') return Colors.red.shade700;
    if (e.result == 'skipped' || e.result == 'stopped') return Colors.orange.shade800;
    if (e.result == 'success') return Colors.green.shade700;
    return Colors.blueGrey;
  }

  String _resultText(LogEntry e) => switch (e.result) {
        'success' => 'بدأ تشغيل الصوت',
        'error' => 'فشل',
        'skipped' => 'تم تجاهل التكرار',
        'stopped' => 'أُوقف يدويًا',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سجل الأحداث'), actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'مسح السجل؟',
                  message: 'سيُحذف كل سجل الأحداث نهائيًا.',
                  confirmText: 'مسح',
                  danger: true);
              if (ok) {
                await app.logs.clear();
                await _load();
              }
            },
          ),
        ]),
        body: Column(children: [
          SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
              for (final e in _kinds.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _kind == e.key,
                    onSelected: (_) {
                      _kind = e.key;
                      _load();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_day == null ? 'كل التواريخ' : ymd(_day!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _day ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (d != null) {
                      _day = d;
                      _load();
                    }
                  },
                ),
              ),
              if (_day != null)
                IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _day = null;
                      _load();
                    }),
            ]),
          ),
          Expanded(
            child: _list == null
                ? const Center(child: CircularProgressIndicator())
                : _list!.isEmpty
                    ? const EmptyState(icon: Icons.history, text: 'لا توجد سجلات')
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _list!.length + 1,
                        itemBuilder: (c, i) {
                          if (i == _list!.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                  '«بدأ تشغيل الصوت» يعني أن التطبيق شغّل الملف فعلًا، ولا يؤكد وصوله إلى المكبرات الخارجية.',
                                  style: TextStyle(fontSize: 12)),
                            );
                          }
                          final e = _list![i];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                  e.kind == 'bell'
                                      ? Icons.notifications
                                      : e.kind == 'error'
                                          ? Icons.error_outline
                                          : e.kind == 'schedule'
                                              ? Icons.update
                                              : Icons.edit_note,
                                  color: _color(e)),
                              title: Text(e.kind == 'bell'
                                  ? '${e.eventLabel ?? 'جرس'} • ${e.mode == 'manual' ? 'يدوي' : 'تلقائي'}'
                                  : (e.message ?? '')),
                              subtitle: Text([
                                '${ymd(e.ts)} ${two(e.ts.hour)}:${two(e.ts.minute)}:${two(e.ts.second)}',
                                if (e.kind == 'bell' && (e.schoolName ?? '').isNotEmpty)
                                  '${e.schoolName} - ${e.buildingName}',
                                if (e.kind == 'bell') _resultText(e),
                                if (e.kind == 'bell' && e.message != null) e.message!,
                              ].where((x) => x.isNotEmpty).join('\n')),
                              isThreeLine: e.kind == 'bell',
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

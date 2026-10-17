import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../app/app_state.dart';
import '../widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File>? _files;
  String? _dir;
  bool _busy = false;
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
    try {
      final d = await app.backup.backupDir();
      final f = await app.backup.list();
      if (mounted) {
        setState(() {
          _dir = d.path;
          _files = f;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _files = []);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final f = await AppScope.read(context).backup.export();
      await AppScope.read(context).logs.change('تصدير نسخة احتياطية: ${p.basename(f.path)}');
      if (mounted) showMsg(context, 'تم التصدير: ${p.basename(f.path)}');
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, 'فشل التصدير: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(File f) async {
    final app = AppScope.read(context);
    final ok = await confirmDialog(context,
        title: 'استعادة النسخة؟',
        message: 'ستُستبدل المدارس والمباني والجداول والإجازات الحالية بمحتوى الملف:\n${p.basename(f.path)}\n'
            'لا يمكن التراجع، لذا يُنصح بتصدير نسخة من البيانات الحالية أولًا.',
        confirmText: 'استعادة',
        danger: true);
    if (!ok) return;
    setState(() => _busy = true);
    final known = app.sounds.map((s) => s.id).toSet();
    final r = await app.backup.restoreFrom(f, knownSounds: known);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      showMsg(context, r.error!, error: true);
      return;
    }
    await app.logs.change('استعادة نسخة احتياطية: ${p.basename(f.path)}');
    if (!mounted) return;
    showMsg(context, r.warnings.isEmpty ? 'تمت الاستعادة بنجاح' : 'تمت الاستعادة مع تنبيهات: ${r.warnings.join('، ')}');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('تصدير نسخة احتياطية الآن'),
                ),
                if (_dir != null) ...[
                  const SizedBox(height: 10),
                  Text('مجلد النسخ:', style: Theme.of(context).textTheme.bodySmall),
                  SelectableText(_dir!, style: const TextStyle(fontSize: 12)),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('نسخ المسار'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _dir!));
                      showMsg(context, 'تم نسخ المسار');
                    },
                  ),
                ],
                const Text(
                    'تشمل النسخة: المدارس والمباني والجداول والإجازات وإعداد قناة الصوت. '
                    'لا تشمل سجل الأحداث. الاستعادة تقرأ الملفات الموجودة في هذا المجلد.',
                    style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text('النسخ المتاحة للاستعادة', style: Theme.of(context).textTheme.titleMedium),
          if (_files == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_files!.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد نسخ محفوظة')))
          else
            for (final f in _files!)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(p.basename(f.path), style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                  trailing: TextButton(onPressed: _busy ? null : () => _restore(f), child: const Text('استعادة')),
                ),
              ),
        ]),
      ),
    );
  }
}

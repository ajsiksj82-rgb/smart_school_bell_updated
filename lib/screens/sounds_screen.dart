import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../features/lesson_progress/models/lesson_progress_models.dart' show BellEventType;
import '../widgets/common.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  double _seconds = 4;
  double _volume = 1;
  bool _busy = false;

  static const _categories = <(BellEventType, String, IconData, Color)>[
    (BellEventType.assemblyStart, 'جرس بداية الطابور', Icons.flag, Color(0xFF6A1B9A)),
    (BellEventType.lessonStart, 'جرس بداية الحصة', Icons.play_circle, Color(0xFF1565C0)),
    (BellEventType.lessonEnd, 'جرس نهاية الحصة', Icons.stop_circle, Color(0xFFEF6C00)),
  ];

  Future<String?> _askName(String suggested) {
    final c = TextEditingController(text: suggested);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اسم الجرس'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'الاسم الذي سيظهر في القوائم'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  Future<void> _import(AppState app, {(BellEventType, String, IconData, Color)? assignTo}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await app.importSound(_askName);
      if (id == null) return;
      if (assignTo != null) await app.setCategorySound(assignTo.$1, id);
      if (mounted) {
        showMsg(context,
            assignTo == null ? 'تم استيراد الجرس' : 'تم استيراد الجرس وتعيينه: ${assignTo.$2}');
      }
    } catch (e) {
      if (mounted) showMsg(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(AppState app, String soundId, String name) async {
    final ok = await app.playBell(
        soundId: soundId,
        durationSec: _seconds.round(),
        volume: _volume,
        label: 'معاينة صوت: $name');
    if (!ok && mounted) showMsg(context, 'يوجد رنين جارٍ أو تعذر التشغيل', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مكتبة الأصوات')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('أجراس المناسبات',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          for (final cat in _categories) _categoryCard(app, cat),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: const Text('استيراد جرس من الجهاز', style: TextStyle(fontSize: 16)),
              onPressed: _busy ? null : () => _import(app),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text('الصيغ المدعومة: MP3 · WAV · M4A · AAC · OGG (حتى 15 ميغابايت).',
                style: TextStyle(fontSize: 12)),
          ),
          AppCard(
            accent: Colors.blueGrey,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اختبار الصوت', style: theme.textTheme.titleMedium),
              Text('مدة المعاينة: ${_seconds.round()} ثانية'),
              Slider(
                  value: _seconds,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setState(() => _seconds = v)),
              Text('مستوى الصوت: ${(_volume * 100).round()}%'),
              Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) => setState(() => _volume = v)),
              const Text(
                'الصوت يخرج عبر المخرج النشط في الهاتف. عند توصيل كابل AUX يوجّهه Android إليه عادةً، '
                'ويتحكم مستوى صوت النظام (المنبّه أو الوسائط حسب الإعدادات) بالشدة النهائية.',
                style: TextStyle(fontSize: 12),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('المكتبة',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          for (final s in app.sounds)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(app.isCustomSound(s) ? Icons.audio_file : Icons.music_note,
                    color: app.isCustomSound(s) ? const Color(0xFFC2185B) : null),
                title: Text(s.name),
                subtitle: Text(app.isCustomSound(s) ? 'مستورد من الجهاز' : 'صوت مضمّن في التطبيق'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (app.isCustomSound(s))
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'حذف الجرس؟',
                            message:
                                'سيُحذف «${s.name}» وستعود الأحداث التي تستخدمه إلى الصوت الافتراضي.',
                            confirmText: 'حذف',
                            danger: true);
                        if (ok) await app.deleteSound(s);
                      },
                    ),
                  IconButton.filled(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _preview(app, s.id, s.name),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('إيقاف الصوت'),
              onPressed: app.stopBell,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الأصوات المضمّنة مولّدة برمجيًا (موجات جيبية) وهي ملك المشروع، عدا «الجرس المرفق» الذي أضافه المطوّر.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
      ),
    );
  }

  Widget _categoryCard(AppState app, (BellEventType, String, IconData, Color) cat) {
    final current = app.categorySounds[cat.$1];
    final valid = app.sounds.any((s) => s.id == current);
    return AppCard(
      accent: cat.$4,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(cat.$3, color: cat.$4),
          const SizedBox(width: 8),
          Expanded(
              child: Text(cat.$2,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('${cat.$1.name}_${valid ? current : 'none'}_${app.sounds.length}'),
              initialValue: valid ? current : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الجرس المعيّن',
                hintText: 'حسب إعداد كل حدث',
                isDense: true,
              ),
              items: [
                for (final s in app.sounds) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await app.setCategorySound(cat.$1, v);
                if (mounted) showMsg(context, 'تم التعيين لكل أحداث: ${cat.$2.replaceFirst('جرس ', '')}');
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'معاينة',
            icon: const Icon(Icons.play_arrow),
            onPressed: valid
                ? () => _preview(
                    app, current!, app.sounds.firstWhere((s) => s.id == current).name)
                : null,
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            tooltip: 'استيراد جرس وتعيينه',
            icon: const Icon(Icons.upload_file),
            onPressed: _busy ? null : () => _import(app, assignTo: cat),
          ),
        ]),
      ]),
    );
  }
}

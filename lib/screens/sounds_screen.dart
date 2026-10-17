import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../widgets/common.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  double _seconds = 4;
  double _volume = 1;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مكتبة الأصوات')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اختبار الصوت', style: Theme.of(context).textTheme.titleMedium),
                Text('مدة المعاينة: ${_seconds.round()} ثانية'),
                Slider(value: _seconds, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _seconds = v)),
                Text('مستوى الصوت: ${(_volume * 100).round()}%'),
                Slider(value: _volume, min: 0, max: 1, divisions: 20, onChanged: (v) => setState(() => _volume = v)),
                const Text(
                  'الصوت يخرج عبر المخرج النشط في الهاتف. عند توصيل كابل AUX يوجّهه Android إليه عادةً، '
                  'ويتحكم مستوى صوت النظام (المنبّه أو الوسائط حسب الإعدادات) بالشدة النهائية.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
          for (final s in app.sounds)
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(s.name),
                subtitle: const Text('صوت مضمّن في التطبيق'),
                trailing: IconButton.filled(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () async {
                    final ok = await app.playBell(
                        soundId: s.id, durationSec: _seconds.round(), volume: _volume, label: 'معاينة صوت: ${s.name}');
                    if (!ok && context.mounted) {
                      showMsg(context, 'يوجد رنين جارٍ أو تعذر التشغيل', error: true);
                    }
                  },
                ),
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
            'الأصوات الأربعة مولّدة برمجيًا خصيصًا للمشروع (موجات جيبية)، وهي ملك المشروع بلا قيود ترخيص خارجية.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

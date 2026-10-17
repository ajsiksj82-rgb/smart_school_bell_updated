import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'common.dart';

/// نافذة الجرس اليدوي: اختيار الصوت والمدة ومستوى الصوت ثم التأكيد.
Future<void> showManualBellSheet(BuildContext context) async {
  final app = AppScope.read(context);
  if (app.selected == null) {
    showMsg(context, 'أضف مدرسة ومبنى أولًا', error: true);
    return;
  }
  var soundId = app.selected!.building.defaultSound ?? (app.sounds.isEmpty ? 'bell_classic' : app.sounds.first.id);
  var seconds = 5.0;
  var volume = app.selected!.building.volume;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تشغيل الجرس يدويًا', style: Theme.of(ctx).textTheme.titleLarge),
              Text(app.selected!.title, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: app.sounds.any((s) => s.id == soundId) ? soundId : null,
                decoration: const InputDecoration(labelText: 'الصوت', border: OutlineInputBorder()),
                items: [for (final s in app.sounds) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setS(() => soundId = v ?? soundId),
              ),
              const SizedBox(height: 8),
              Text('مدة الرنين: ${seconds.round()} ثانية'),
              Slider(value: seconds, min: 1, max: 60, divisions: 59, onChanged: (v) => setS(() => seconds = v)),
              Text('مستوى الصوت: ${(volume * 100).round()}%'),
              Slider(value: volume, min: 0, max: 1, divisions: 20, onChanged: (v) => setS(() => volume = v)),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text('تشغيل الآن'),
                onPressed: () async {
                  final ok = await confirmDialog(ctx,
                      title: 'تأكيد تشغيل الجرس',
                      message: 'سيُشغَّل الجرس الآن عبر مكبرات الصوت المتصلة. هل تريد المتابعة؟',
                      confirmText: 'تشغيل');
                  if (!ok) return;
                  final started = await app.playBell(
                      soundId: soundId, durationSec: seconds.round(), volume: volume);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    showMsg(context, started ? 'بدأ تشغيل الجرس' : 'تعذر التشغيل: يوجد رنين جارٍ أو حدث خطأ',
                        error: !started);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

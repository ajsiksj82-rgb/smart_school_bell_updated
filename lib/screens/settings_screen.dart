import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => AppScope.read(context).refreshStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppScope.read(context).refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _perm({
    required bool ok,
    required String title,
    required String why,
    required String button,
    required VoidCallback onTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded,
                color: ok ? Colors.green.shade700 : Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 6),
          Text(why, style: const TextStyle(fontSize: 13)),
          if (!ok) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onTap, child: Text(button)),
          ],
        ]),
      ),
    );
  }

  Widget _usageTile(AppState app, String value, String title, String sub) {
    final selected = app.audioUsage == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null),
      title: Text(title),
      subtitle: Text(sub),
      onTap: () => app.setAudioUsage(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات والصلاحيات')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          _perm(
            ok: app.exactAllowed,
            title: 'التنبيهات الدقيقة',
            why: 'لازمة ليرنّ الجرس في الدقيقة المحددة. بدونها قد يتأخر Android بالتنبيه عدة دقائق.',
            button: 'فتح إعدادات التنبيهات الدقيقة',
            onTap: app.native.openExactAlarmSettings,
          ),
          _perm(
            ok: app.batteryIgnored,
            title: 'استثناء من توفير البطارية',
            why: 'بعض الشركات المصنّعة تقتل التطبيقات في الخلفية وتؤخر التنبيهات. يُنصح باستثناء التطبيق، '
                'وتعطيل «تحسين البطارية» الخاص بالشركة المصنّعة إن وُجد.',
            button: 'فتح إعدادات البطارية',
            onTap: app.native.openBatterySettings,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الإشعارات', style: Theme.of(context).textTheme.titleMedium),
                const Text('يعرض Android إشعارًا أثناء الرنين (مع زر إيقاف). الرنين يعمل حتى لو رُفض الإذن.',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilledButton.tonal(onPressed: app.native.requestNotifications, child: const Text('طلب الإذن')),
                  OutlinedButton(onPressed: app.native.openNotificationSettings, child: const Text('إعدادات الإشعارات')),
                ]),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('قناة الصوت', style: Theme.of(context).textTheme.titleMedium),
                _usageTile(app, 'alarm', 'مستوى صوت المنبّه',
                    'يرنّ حتى في الوضع الصامت، ويتحكم به مستوى صوت المنبّه في الهاتف.'),
                _usageTile(app, 'media', 'مستوى صوت الوسائط',
                    'يتبع مستوى صوت الوسائط (مناسب غالبًا لأنظمة المكبرات عبر AUX).'),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('حالة الجدولة', style: Theme.of(context).textTheme.titleMedium),
                Text(app.scheduledCount < 0
                    ? 'فشلت الجدولة — راجع السجل.'
                    : 'عدد الأجراس المجدولة: ${app.scheduledCount} (الأيام الـ14 القادمة)'),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.update),
                  label: const Text('إعادة الجدولة الآن'),
                  onPressed: () async {
                    await app.rebuildSchedule(reason: 'change');
                    if (context.mounted) showMsg(context, 'تمت إعادة الجدولة');
                  },
                ),
              ]),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'قيود لا يمكن تجاوزها برمجيًا:\n'
                '• لا يرنّ الجرس إذا كان الهاتف مطفأً أو نفدت بطاريته.\n'
                '• قد تمنع بعض الشركات المصنّعة التنبيهات إذا قُيّد التطبيق في الخلفية.\n'
                '• تُجدول الأجراس للأيام الـ14 القادمة، فافتح التطبيق مرة على الأقل كل أسبوعين.\n'
                '• الأجراس التي تفوتها أثناء إغلاق الهاتف لا تُعوَّض بعد التشغيل.\n'
                '• لا يستطيع التطبيق اكتشاف قطع كابل AUX بدقة ولا التأكد من وصول الصوت للمكبرات؛ '
                'سجل التشغيل يثبت بدء تشغيل الملف فقط.\n'
                '• إدارة عدة مدارس من هاتف واحد لا تعني رنين جرس مواقع بعيدة: كل موقع يحتاج هاتفًا متصلًا بنظام صوته.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

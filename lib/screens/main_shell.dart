import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'holidays_screen.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'schedule_hub_screen.dart';
import 'schools_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';

/// الهيكل الرئيسي: شريط تنقّل سفلي بين الأدوات الأساسية.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sel = app.selected;

    final tabs = <Widget>[
      const HomeScreen(),
      sel == null
          ? const _NeedBuilding()
          : ScheduleHubScreen(
              key: ValueKey(sel.building.id), building: sel.building, schoolName: sel.schoolName),
      const SoundsScreen(),
      const HolidaysScreen(),
      const MoreScreen(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // لكل تبويب ScaffoldMessenger خاص به كي لا تتكرر رسائل SnackBar بين الشاشات.
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _visited.contains(i) ? ScaffoldMessenger(child: tabs[i]) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() {
              _index = i;
              _visited.add(i);
            }),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
              NavigationDestination(
                  icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'الجدول'),
              NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'الأصوات'),
              NavigationDestination(
                  icon: Icon(Icons.beach_access_outlined),
                  selectedIcon: Icon(Icons.beach_access),
                  label: 'الإجازات'),
              NavigationDestination(
                  icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'المزيد'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedBuilding extends StatelessWidget {
  const _NeedBuilding();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الجدول')),
        body: EmptyState(
          icon: Icons.business,
          text: 'أضف مدرسة ومبنى أولًا ثم اضبط جدول الأجراس',
          action: FilledButton.icon(
            icon: const Icon(Icons.add_business),
            label: const Text('المدارس والمباني'),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchoolsScreen())),
          ),
        ),
      ),
    );
  }
}

/// الأدوات الأقل استخدامًا.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final items = <(IconData, String, String, Color, Widget)>[
      (Icons.business, 'المدارس والمباني', 'إضافة مدرسة أو مبنى وتعديلهما', const Color(0xFF00796B),
          const SchoolsScreen()),
      (Icons.history, 'السجل', 'سجل تنفيذ الأجراس والتغييرات', const Color(0xFF546E7A), const LogsScreen()),
      (Icons.backup, 'النسخ الاحتياطي', 'تصدير البيانات واستعادتها', const Color(0xFF2E7D32),
          const BackupScreen()),
      (Icons.settings, 'الإعدادات والصلاحيات', 'التنبيهات الدقيقة وقناة الصوت والبطارية',
          const Color(0xFF455A64), const SettingsScreen()),
      (Icons.person, 'عن المطوّر', 'أحمد داود طه شريف', const Color(0xFFC2185B), const AboutScreen()),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المزيد')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.all(12), children: [
                for (final it in items)
                  AppCard(
                    accent: it.$4,
                    onTap: () => push(it.$5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: it.$4.withAlpha(28), shape: BoxShape.circle),
                        child: Icon(it.$1, color: it.$4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.$2,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(it.$3, style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                      const Icon(Icons.chevron_left),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

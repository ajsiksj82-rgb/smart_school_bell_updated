import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart' show kPrimary, kSecondary;
import '../widgets/common.dart';

/// بيانات المطوّر (مكان واحد لتعديلها).
const String kDeveloperName = 'أحمد داود طه شريف';
const String kDeveloperPhone = '771274134';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kDeveloperPhone));
    if (context.mounted) showMsg(context, 'تم نسخ رقم الهاتف');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('عن التطبيق والمطوّر')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [kPrimary, kSecondary],
                      ),
                    ),
                    child: Column(children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active,
                            color: Colors.white, size: 42),
                      ),
                      const SizedBox(height: 12),
                      const Text('الجرس المدرسي الذكي',
                          style: TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Smart School Bell • الإصدار 1.0.0',
                          style: TextStyle(color: Colors.white.withAlpha(220))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    accent: kPrimary,
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('معلومات المطوّر',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Row(children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: kPrimary,
                          child: Icon(Icons.person, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text(kDeveloperName,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('مطوّر التطبيق', style: theme.textTheme.bodySmall),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_android, color: kPrimary),
                        title: const Text('للتواصل والدعم'),
                        subtitle: const Directionality(
                          textDirection: TextDirection.ltr,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(kDeveloperPhone,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'نسخ الرقم',
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copy(context),
                        ),
                        onTap: () => _copy(context),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

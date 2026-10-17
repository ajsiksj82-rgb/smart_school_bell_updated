import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    final state = AppState(db);
    await state.init();
    runApp(SmartSchoolBellApp(state: state));
  } catch (e) {
    runApp(MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('تعذّر تشغيل التطبيق:\n$e', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ));
  }
}
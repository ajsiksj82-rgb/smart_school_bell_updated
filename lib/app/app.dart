import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../screens/main_shell.dart';
import 'app_state.dart';

const Color kPrimary = Color(0xFF0D2B5E);
const Color kSecondary = Color(0xFF4FA3E0);

class SmartSchoolBellApp extends StatelessWidget {
  const SmartSchoolBellApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'الجرس المدرسي الذكي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, secondary: kSecondary),
          scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 2,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: kSecondary.withAlpha(60),
            height: 68,
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
                  color: states.contains(WidgetState.selected) ? kPrimary : Colors.blueGrey.shade600,
                )),
            iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                  color: states.contains(WidgetState.selected) ? kPrimary : Colors.blueGrey.shade600,
                )),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

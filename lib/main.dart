import 'package:flutter/material.dart';
import 'package:echo_bible/features/home/screens/main_navigation_screen.dart'; // Vérifie le chemin exact
import 'package:echo_bible/features/plans/services/reading_reminder_service.dart';
import 'package:echo_bible/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReadingReminderService.initialize();
  runApp(const EchoBibleApp());
}

class EchoBibleApp extends StatelessWidget {
  const EchoBibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo Bible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home:
          const MainNavigationScreen(), // Utilise le nom exact de ton écran principal
    );
  }
}

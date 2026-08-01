import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_scaffold.dart';
import 'theme/theme_provider.dart';
import 'services/lesson_service.dart';
import 'services/vocabulary_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/profile_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LessonService()),
        ChangeNotifierProvider(create: (_) => VocabularyService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'DeutschApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(themeProvider.fontFamily, themeProvider.colorTheme),
      darkTheme: AppTheme.darkTheme(themeProvider.fontFamily, themeProvider.colorTheme),
      themeMode: themeProvider.themeMode,
      home: const MainScaffold(initialIndex: 1),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/theme/app_theme.dart';
import 'package:prototype/providers/theme_provider.dart';
import 'package:prototype/screens/home_screen.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/providers/settings_provider.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:prototype/providers/message_provider.dart';
import 'package:prototype/providers/schedule_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..loadTheme(),
        ),
        ChangeNotifierProvider<PlantDataProvider>(
          create: (_) => PlantDataProvider()..init(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider()..init(),
        ),
        ChangeNotifierProvider<MessageProvider>(
          create: (_) => MessageProvider(),
        ),
        ChangeNotifierProvider<ScheduleProvider>(
          create: (_) => ScheduleProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Plant Monitor',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

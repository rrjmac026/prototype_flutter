import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/theme/app_theme.dart';
import 'package:prototype/providers/theme_provider.dart';
import 'package:prototype/screens/home_screen.dart';
import 'package:prototype/screens/login_screen.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/providers/settings_provider.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:prototype/providers/message_provider.dart';
import 'package:prototype/providers/schedule_provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/screens/admin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..loadTheme(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..init(),
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
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, child) {
        return MaterialApp(
          title: 'Plant Monitor',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: _buildHome(authProvider),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/admin': (context) => const AdminScreen(),
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          },
        );
      },
    );
  }

  Widget _buildHome(AuthProvider authProvider) {
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // Route based on role
    if (authProvider.isAdmin()) {
      return const AdminScreen();
    }

    return const HomeScreen();
  }
}

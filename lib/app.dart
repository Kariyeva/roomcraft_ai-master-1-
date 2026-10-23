import 'package:flutter/material.dart';

import 'screens/01_splash.dart';
import 'theme/app_theme.dart';
import 'screens/02_login.dart';
import 'screens/03_mode_select.dart';
import 'screens/04_ai_create.dart';
import 'screens/05_result.dart';
import 'screens/06_editor.dart';
import 'screens/workspace_screen.dart';
import 'screens/create_project_screen.dart';
import 'screens/profile_screen.dart';

class RoomCraftApp extends StatelessWidget {
  const RoomCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoomCraft AI',
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/projects': (_) => const WorkspaceScreen(showProjects: true),
        '/project/new': (_) => const CreateProjectScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/mode': (context) => const ModeSelectScreen(),
        '/ai_create': (context) => const AiCreateScreen(),
        '/result': (context) => const ResultScreen(),
        '/editor': (context) => const EditorScreen(),
      },
    );
  }
}

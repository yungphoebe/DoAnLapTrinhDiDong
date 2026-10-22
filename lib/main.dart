import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/auth_service.dart';
import 'screens/auth.dart';
import 'screens/pose_camera.dart';
import 'screens/workout_history.dart';
import 'screens/workout_plans.dart';
import 'screens/onboarding.dart';
import 'screens/reset_password.dart';
import 'screens/settings.dart';
import 'screens/nutrition.dart';
import 'screens/shell.dart';
import 'ai_test_page.dart';
import 'ui.dart';
import 'notifications/runtime.dart';
import 'notifications/screens.dart';
import 'notifications/settings_screen.dart';
import 'notifications/api.dart';
import 'support/screens.dart';
import 'models/workout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: GymColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(NotificationRuntime(child: MainApp(initialRoute: _initialRoute())));
}

String _initialRoute() {
  final fragment = Uri.base.fragment;
  if (fragment.startsWith('/reset-password')) {
    return fragment;
  }
  return NotificationApi().owner != null ? '/home' : '/login';
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.initialRoute = '/login'});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: appNavigatorKey,
    title: 'AI GYM',
    debugShowCheckedModeBanner: false,
    theme: gymTheme(),
    initialRoute: initialRoute,
    routes: {
      '/': (_) => const AuthScreen(),
      '/login': (_) => const AuthScreen(),
      '/register': (_) => const AuthScreen(register: true),
      '/forgot': (_) => const AuthScreen(forgot: true),
      '/onboarding': (_) => const OnboardingScreen(),
      '/home': (_) => const AppShell(),
      '/workout-history': (_) => const WorkoutHistoryScreen(),
      '/workout-plans': (_) => const WorkoutPlansScreen(),
      '/settings': (_) => const SettingsScreen(),
      '/nutrition': (_) => const NutritionScreen(),
      '/coach-settings': (_) => const CoachSettingsScreen(),
      '/notifications': (_) => const NotificationsScreen(),
      '/reminder-settings': (_) => const ReminderSettingsScreen(),
      '/support': (_) => const SupportScreen(),
      '/feedback': (_) => const FeedbackScreen(),
      '/terms': (_) => const SupportScreen(document: 'terms'),
      '/privacy': (_) => const SupportScreen(document: 'privacy'),
    },
    onGenerateRoute: (settings) {
      final route = Uri.parse(settings.name ?? '');
      final kind = switch (route.path) {
        '/workouts' => 'workout',
        '/water' => 'water',
        '/weekly-report' => 'weekly',
        _ => null,
      };
      if (kind != null) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => NotificationDestinationScreen(
            kind: kind,
            at: DateTime.tryParse(route.queryParameters['at'] ?? ''),
      '/ai-test': (_) => const AITestPage(),
    },
    onGenerateRoute: (settings) {
      final route = Uri.parse(settings.name ?? '');
      if (route.path == '/camera') {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PoseCameraScreen(
            exercise: settings.arguments is Exercise
                ? settings.arguments as Exercise
                : null,
          ),
        );
      }
      if (route.path == '/reset-password') {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ResetPasswordScreen(
            email: route.queryParameters['email'] ?? '',
            token: route.queryParameters['token'] ?? '',
          ),
        );
      }
      return null;
    },
    builder: (context, child) => ColoredBox(
      color: const Color(0xFF09090B),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRect(child: child!),
        ),
      ),
    ),
  );
}

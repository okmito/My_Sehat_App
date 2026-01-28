import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/pages/login_screen.dart';
import '../../../features/auth/presentation/pages/profile_screen.dart';
import '../../../features/home/presentation/pages/home_screen.dart';
import '../../../features/emergency/presentation/pages/sos_screen.dart';
import '../../../features/emergency/presentation/pages/emergency_contacts_screen.dart';
import '../../../features/symptom_check/presentation/pages/symptom_checker_screen.dart';
import '../../../features/mental_health/presentation/pages/mental_health_screen.dart';
import '../../../features/appointment/presentation/pages/appointment_screen.dart';
import '../../../features/intro/presentation/pages/splash_screen.dart';
import '../../../features/settings/presentation/pages/language_selection_screen.dart';
import '../../../features/settings/presentation/pages/app_info_screen.dart';
import '../../../features/settings/presentation/pages/help_support_screen.dart';
import '../../../features/settings/presentation/pages/settings_screen.dart';
import 'main_wrapper_screen.dart';

import '../../../features/search/presentation/pages/search_screen.dart';
import '../../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../../features/history/presentation/pages/history_screen.dart';
import '../../../features/daily_journal/journal_list_page.dart';
import '../../../features/stress_games/stress_games_page.dart';
import '../../../features/medicine_reminder/medicine_reminder_page.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/', // Start at Splash
    redirect: (context, state) {
      // Logic moved to Splash Screen for initial load,
      // but we might want to keep some protection here.
      // For now, let Splash handle the initial logic to avoid immediate redirects.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Stateful Shell Route for Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainWrapperScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // Branch 2: SOS (Quick Access)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sos-quick', // Differentiate from full screen if needed
                builder: (context, state) => const SOSScreen(),
              ),
            ],
          ),
          // Branch 3: Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          // Branch 4: History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full Screen Routes (Not in Bottom Bar)
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/language-selection',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: '/appointment',
        builder: (context, state) => const AppointmentScreen(),
      ),
      GoRoute(
        path: '/sos',
        builder: (context, state) =>
            const SOSScreen(), // Currently reusing, might want specific formatting
      ),
      GoRoute(
        path: '/symptom',
        builder: (context, state) => const SymptomCheckerScreen(),
      ),
      GoRoute(
        path: '/mental_health',
        builder: (context, state) => const MentalHealthScreen(),
      ),
      GoRoute(
        path: '/app-info',
        builder: (context, state) => const AppInfoScreen(),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/daily_journal',
        builder: (context, state) => const JournalListPage(),
      ),
      GoRoute(
        path: '/stress_games',
        builder: (context, state) => const StressGamesPage(),
      ),
      GoRoute(
        path: '/medicine_reminder',
        builder: (context, state) => const MedicineReminderPage(),
      ),
    ],
  );
});

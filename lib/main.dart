import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/local_storage_service.dart';
import 'features/emergency/presentation/providers/emergency_contacts_provider.dart';
import 'core/providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStorage = LocalStorageService();
  await localStorage.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
        emergencyContactsProvider.overrideWith(
          (ref) => EmergencyContactsNotifier(localStorage.emergencyContactsBox),
        ),
        languageProvider.overrideWith(
          (ref) => LanguageNotifier(localStorage.settingsBox),
        ),
      ],
      child: const MySehatApp(),
    ),
  );
}

class MySehatApp extends ConsumerWidget {
  const MySehatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'MySehat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

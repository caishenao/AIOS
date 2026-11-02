import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/app_theme.dart';
import 'pages/app_shell.dart';
import 'pages/config_page.dart';
import 'pages/integrated_main_page.dart';
import 'pages/project_management_page.dart';
import 'pages/asset_definition_page.dart';
import 'genui/catalog/catalog_registry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CatalogRegistry.instance.registerAll();
  runApp(const ProviderScope(child: HomeStewardApp()));
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/config',
        builder: (context, state) => const ConfigPage(),
      ),
      GoRoute(
        path: '/conversation',
        builder: (context, state) {
          final initialCommand = state.extra as String?;
          return IntegratedMainPage(initialCommand: initialCommand);
        },
      ),
      GoRoute(
        path: '/project-management',
        builder: (context, state) => const ProjectManagementPage(),
      ),
      GoRoute(
        path: '/asset-definition',
        builder: (context, state) => const AssetDefinitionPage(),
      ),
    ],
  );
});

class HomeStewardApp extends ConsumerWidget {
  const HomeStewardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Home Steward',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

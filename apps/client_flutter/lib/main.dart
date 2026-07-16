import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/config_page.dart';
import 'pages/integrated_main_page.dart';
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
        builder: (context, state) => const IntegratedMainPage(),
      ),
      GoRoute(
        path: '/config',
        builder: (context, state) => const ConfigPage(),
      ),
    ],
  );
});

class HomeStewardApp extends ConsumerWidget {
  const HomeStewardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Home Steward',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05050A), // deep dark tech background
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0D0D16),
          primary: Color(0xFF00F0FF), // Neon Cyan
          secondary: Color(0xFF8A2BE2), // Neon Purple
        ),
        // textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

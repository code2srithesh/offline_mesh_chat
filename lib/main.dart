import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/storage_service.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized prior to calling async plugins
  WidgetsFlutterBinding.ensureInitialized();
  
  await StorageService().init();
  
  runApp(
    const ProviderScope(
      child: OfflineMeshApp(),
    ),
  );
}

class OfflineMeshApp extends ConsumerWidget {
  const OfflineMeshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch themePaletteProvider to trigger rebuilds on theme change
    final themePalette = ref.watch(themePaletteProvider);
    final isLight = themePalette.id == 'light';

    return MaterialApp(
      title: 'OfflineMesh Chat',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

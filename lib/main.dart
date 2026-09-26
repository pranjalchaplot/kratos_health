import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/soma_theme.dart';
import 'providers/soma_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: SomaColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => SomaProvider(),
      child: const SomaApp(),
    ),
  );
}

class SomaApp extends StatelessWidget {
  const SomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOMA | Performance Ecosystem',
      debugShowCheckedModeBanner: false,
      theme: SomaTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

// Backwards compatibility alias
typedef KratosApp = SomaApp;

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: SomaColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'asset/icon_data/playstore.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.bolt,
                    size: 64,
                    color: SomaColors.primaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: SomaColors.primaryContainer,
              ),
            ],
          ),
        ),
      );
    }

    if (!provider.isOnboardingCompleted) {
      return const OnboardingScreen();
    }

    Widget bodyWidget;
    switch (provider.currentTabIndex) {
      case 0:
        bodyWidget = const DashboardScreen();
        break;
      case 1:
        bodyWidget = const LogsScreen();
        break;
      case 3:
        bodyWidget = const LibraryScreen();
        break;
      case 4:
        bodyWidget = const ProfileScreen();
        break;
      default:
        bodyWidget = const DashboardScreen();
    }

    return Scaffold(
      backgroundColor: SomaColors.background,
      body: Stack(
        children: [
          bodyWidget,
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SomaBottomNav(),
          ),
        ],
      ),
    );
  }
}

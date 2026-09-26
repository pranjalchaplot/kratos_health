import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/kratos_theme.dart';
import 'providers/kratos_provider.dart';
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
    systemNavigationBarColor: KratosColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => KratosProvider(),
      child: const KratosApp(),
    ),
  );
}

class KratosApp extends StatelessWidget {
  const KratosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KRATOS | Performance Ecosystem',
      debugShowCheckedModeBanner: false,
      theme: KratosTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratosProvider>();

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: KratosColors.background,
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
                    color: KratosColors.primaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: KratosColors.primaryContainer,
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
      backgroundColor: KratosColors.background,
      body: Stack(
        children: [
          bodyWidget,
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: KratosBottomNav(),
          ),
        ],
      ),
    );
  }
}

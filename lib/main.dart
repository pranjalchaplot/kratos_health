import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/kratos_theme.dart';
import 'screens/dashboard_screen.dart';
import 'models/dashboard_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: KratosColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const KratosApp());
}

class KratosApp extends StatelessWidget {
  const KratosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate mock data representing the dynamic state
    final dashboardData = DashboardData.mock();

    return MaterialApp(
      title: 'KRATOS | Performance Dashboard',
      debugShowCheckedModeBanner: false,
      theme: KratosTheme.darkTheme,
      home: DashboardScreen(data: dashboardData),
    );
  }
}


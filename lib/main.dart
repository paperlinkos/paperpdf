import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

import 'services/entitlement_service.dart';
import 'services/usage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UsageService().init();
  unawaited(EntitlementService().initialize());
  runApp(const PaperLinkApp());
}

// Helper for fire-and-forget initialization
void unawaited(Future<void> future) {}

class PaperLinkApp extends StatelessWidget {
  const PaperLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaperLink PDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

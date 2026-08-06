import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics_service.dart';
import 'main_scaffold.dart';
import 'welcome_screen.dart';

/// Decides whether a fresh install sees onboarding or drops straight into
/// the app. This was previously undecided at all — WelcomeScreen existed
/// but nothing ever navigated to it, so every user (including first-run)
/// landed on MainScaffold with zero introduction.
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  static const String hasSeenOnboardingKey = 'has_seen_onboarding_v1';

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _hasSeenOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(AppEntryPoint.hasSeenOnboardingKey) ?? false;
      if (!seen) {
        AnalyticsService.logEvent('onboarding_started');
      }
      if (mounted) {
        setState(() => _hasSeenOnboarding = seen);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _hasSeenOnboarding
        ? const MainScaffold(initialIndex: 0)
        : const WelcomeScreen();
  }
}

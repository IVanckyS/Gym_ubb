import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProvider extends ChangeNotifier {
  bool _completed = false;
  bool _initialized = false;

  bool get isCompleted => _completed;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool('onboarding_completed') ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('terms_accepted', true);
    _completed = true;
    notifyListeners();
  }

  /// Solo para desarrollo: resetea el onboarding para volver a verlo.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
    await prefs.remove('terms_accepted');
    await prefs.remove('notifications_enabled');
    _completed = false;
    notifyListeners();
  }
}

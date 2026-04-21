import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lbs }

class WeightUnitNotifier extends ChangeNotifier {
  WeightUnit _unit = WeightUnit.kg;

  WeightUnit get unit => _unit;
  bool get isKg => _unit == WeightUnit.kg;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('weight_unit');
    _unit = saved == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;
    notifyListeners();
  }

  Future<void> setUnit(WeightUnit unit) async {
    _unit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit == WeightUnit.lbs ? 'lbs' : 'kg');
  }

  String get label => _unit == WeightUnit.lbs ? 'lbs' : 'kg';
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DefaultRoutineProvider extends ChangeNotifier {
  static const _keyId = 'default_routine_id';
  static const _keyName = 'default_routine_name';

  String? _routineId;
  String? _routineName;

  String? get routineId => _routineId;
  String? get routineName => _routineName;
  bool get hasDefault => _routineId != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _routineId = prefs.getString(_keyId);
    _routineName = prefs.getString(_keyName);
    notifyListeners();
  }

  Future<void> setDefault(String id, String name) async {
    _routineId = id;
    _routineName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, id);
    await prefs.setString(_keyName, name);
    notifyListeners();
  }

  Future<void> clear() async {
    _routineId = null;
    _routineName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
    notifyListeners();
  }
}

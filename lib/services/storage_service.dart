import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StudyStorageService {
  static const String _keyState = 'kr_step_by_step_state_v1';

  Future<Map<String, dynamic>> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyState);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyState, jsonEncode(state));
  }
}

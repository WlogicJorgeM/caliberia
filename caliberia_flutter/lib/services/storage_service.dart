import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ballistic_analysis.dart';

class StorageService {
  static const _sessionKey = 'caliberia_session';
  static const _historyKey = 'caliberia_history';

  // Session
  static Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  static Future<void> saveSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, email);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // History
  static Future<List<BallisticAnalysis>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => BallisticAnalysis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(List<BallisticAnalysis> history) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, raw);
  }
}

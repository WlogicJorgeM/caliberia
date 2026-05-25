import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../models/ballistic_analysis.dart';

class StorageService {
  static const _historyKey = 'caliberia_history_v2';
  static const _sessionKey = 'caliberia_session';
  static const _sessionTimestampKey = 'caliberia_session_ts';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // ═══════════════════════════════════════════════════════
  // AUTENTICACIÓN
  // ═══════════════════════════════════════════════════════

  /// Hash de contraseña con SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Validar credenciales (hash comparado)
  static bool validateCredentials(String email, String password) {
    // Hash pre-calculado de '123'
    const validEmail = 'admin@admin.com';
    const validPasswordHash =
        'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3';
    return email == validEmail && hashPassword(password) == validPasswordHash;
  }

  /// Guardar sesión con timestamp
  static Future<void> saveSession(String email) async {
    await _secure.write(key: _sessionKey, value: email);
    await _secure.write(
        key: _sessionTimestampKey,
        value: DateTime.now().millisecondsSinceEpoch.toString());
    AppLogger.info('Sesión guardada para: $email');
  }

  /// Obtener sesión activa (null si expiró)
  static Future<String?> getSession() async {
    final email = await _secure.read(key: _sessionKey);
    if (email == null) return null;

    final tsStr = await _secure.read(key: _sessionTimestampKey);
    if (tsStr != null) {
      final ts = int.tryParse(tsStr) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - ts;
      final maxMs = AppConstants.sessionTimeoutMinutes * 60 * 1000;
      if (elapsed > maxMs) {
        AppLogger.info('Sesión expirada');
        await clearSession();
        return null;
      }
    }

    return email;
  }

  /// Cerrar sesión
  static Future<void> clearSession() async {
    await _secure.delete(key: _sessionKey);
    await _secure.delete(key: _sessionTimestampKey);
  }

  // ═══════════════════════════════════════════════════════
  // HISTORIAL
  // ═══════════════════════════════════════════════════════

  /// Obtener historial con límite
  static Future<List<BallisticAnalysis>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final List<dynamic> list = jsonDecode(raw);
      final history = list
          .map((e) => BallisticAnalysis.fromJson(e as Map<String, dynamic>))
          .toList();
      AppLogger.debug('Historial cargado: ${history.length} registros');
      return history;
    } catch (e) {
      AppLogger.error('Error al cargar historial', e);
      return [];
    }
  }

  /// Guardar historial (con límite de registros)
  static Future<void> saveHistory(List<BallisticAnalysis> history) async {
    // Limitar cantidad de registros
    final limited = history.length > AppConstants.maxHistoryItems
        ? history.sublist(0, AppConstants.maxHistoryItems)
        : history;

    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(limited.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, raw);
    AppLogger.debug('Historial guardado: ${limited.length} registros');
  }

  /// Eliminar un registro del historial
  static Future<void> deleteFromHistory(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e.id == id);
    await saveHistory(history);
  }

  /// Limpiar todo el historial
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    AppLogger.info('Historial eliminado');
  }
}

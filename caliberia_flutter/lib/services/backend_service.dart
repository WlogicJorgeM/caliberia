import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/app_logger.dart';
import '../models/ballistic_analysis.dart';

/// Servicio para comunicarse con el backend (PostgreSQL)
class BackendService {
  static String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  static String? _token;
  static int? _userId;

  static int? get userId => _userId;
  static bool get isAuthenticated => _token != null;

  /// Login contra el backend
  static Future<Map<String, dynamic>?> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _userId = data['user']['id'];
        AppLogger.info('Login exitoso via backend (userId: $_userId)');
        return data['user'] as Map<String, dynamic>;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Error de autenticación');
      }
    } catch (e) {
      AppLogger.warning('Backend no disponible, usando auth local: $e');
      return null; // Fallback a auth local
    }
  }

  /// Guardar análisis en PostgreSQL
  static Future<bool> saveAnalysis(BallisticAnalysis analysis) async {
    if (_token == null || _userId == null) return false;

    try {
      final body = analysis.toJson();
      body['userId'] = _userId;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/analysis/save'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        AppLogger.info('Análisis guardado en PostgreSQL: ${analysis.id}');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.warning('No se pudo guardar en backend: $e');
      return false;
    }
  }

  /// Obtener historial desde PostgreSQL
  static Future<List<BallisticAnalysis>?> getHistory() async {
    if (_token == null || _userId == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/analysis/history/$_userId'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['analyses'] as List;
        return list
            .map((e) => BallisticAnalysis.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (e) {
      AppLogger.warning('No se pudo obtener historial del backend: $e');
      return null;
    }
  }

  /// Eliminar análisis
  static Future<bool> deleteAnalysis(String id) async {
    if (_token == null) return false;

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/analysis/delete/$id'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Actualizar notas
  static Future<bool> updateNotes(String id, String notes) async {
    if (_token == null) return false;

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/analysis/notes/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({'notes': notes}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Enviar feedback (up/down) para un análisis
  static Future<bool> sendFeedback(String id, String feedback) async {
    if (_token == null) return false;

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/analysis/feedback/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({'feedback': feedback}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Obtener ejemplos validados para few-shot learning (positivos y negativos)
  static Future<Map<String, List<Map<String, dynamic>>>> getValidatedExamples() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/analysis/validated-examples'),
            headers: _token != null
                ? {'Authorization': 'Bearer $_token'}
                : {},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'positives': List<Map<String, dynamic>>.from(data['positives'] ?? []),
          'negatives': List<Map<String, dynamic>>.from(data['negatives'] ?? []),
        };
      }
      return {'positives': [], 'negatives': []};
    } catch (_) {
      return {'positives': [], 'negatives': []};
    }
  }

  /// Obtener estadísticas
  static Future<Map<String, dynamic>?> getStats() async {
    if (_token == null || _userId == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/analysis/stats/$_userId'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verificar si el backend está disponible
  static Future<bool> isAvailable() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Logout
  static void logout() {
    _token = null;
    _userId = null;
  }
}

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import '../database.dart';

class AnalysisRoutes {
  final Database db;

  AnalysisRoutes(this.db);

  Router get router {
    final r = Router();
    r.post('/save', _saveAnalysis);
    r.get('/history/<userId>', _getHistory);
    r.delete('/delete/<id>', _deleteAnalysis);
    r.put('/notes/<id>', _updateNotes);
    r.put('/feedback/<id>', _updateFeedback);
    r.get('/validated-examples', _getValidatedExamples);
    r.get('/stats/<userId>', _getStats);
    return r;
  }

  /// POST /api/analysis/save
  Future<Response> _saveAnalysis(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      await db.connection.execute(
        Sql.named('''
          INSERT INTO analyses (id, user_id, image_base64, caliber, ammo_type, 
            compatible_weapon, estimated_length, possible_brands, confidence, 
            description, ai_provider, response_time_ms, notes)
          VALUES (@id, @userId, @image, @caliber, @ammoType, @weapon, 
            @length, @brands, @confidence, @description, @provider, @time, @notes)
        '''),
        parameters: {
          'id': body['id'],
          'userId': body['userId'],
          'image': body['imageBase64'],
          'caliber': body['results']['caliber'],
          'ammoType': body['results']['ammoType'],
          'weapon': body['results']['compatibleWeapon'],
          'length': body['results']['estimatedLength'],
          'brands': (body['results']['possibleBrands'] as List).cast<String>(),
          'confidence': body['results']['confidence'],
          'description': body['results']['description'],
          'provider': body['aiProvider'],
          'time': body['responseTimeMs'],
          'notes': body['notes'] ?? '',
        },
      );

      return _jsonResponse(201, {'message': 'Análisis guardado'});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error al guardar: $e'});
    }
  }

  /// GET /api/analysis/history/:userId
  Future<Response> _getHistory(Request req, String userId) async {
    try {
      final result = await db.connection.execute(
        Sql.named('''
          SELECT id, image_base64, caliber, ammo_type, compatible_weapon,
            estimated_length, possible_brands, confidence, description,
            ai_provider, response_time_ms, notes, 
            EXTRACT(EPOCH FROM created_at)::bigint * 1000 as timestamp
          FROM analyses 
          WHERE user_id = @userId 
          ORDER BY created_at DESC 
          LIMIT 100
        '''),
        parameters: {'userId': int.parse(userId)},
      );

      final analyses = result.map((row) => {
            'id': row[0],
            'imageBase64': row[1],
            'results': {
              'caliber': row[2],
              'ammoType': row[3],
              'compatibleWeapon': row[4],
              'estimatedLength': row[5],
              'possibleBrands': row[6],
              'confidence': row[7],
              'description': row[8],
            },
            'aiProvider': row[9],
            'responseTimeMs': row[10],
            'notes': row[11],
            'timestamp': row[12],
          }).toList();

      return _jsonResponse(200, {'analyses': analyses});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error al obtener historial: $e'});
    }
  }

  /// DELETE /api/analysis/delete/:id
  Future<Response> _deleteAnalysis(Request req, String id) async {
    try {
      await db.connection.execute(
        Sql.named('DELETE FROM analyses WHERE id = @id'),
        parameters: {'id': id},
      );
      return _jsonResponse(200, {'message': 'Análisis eliminado'});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error al eliminar: $e'});
    }
  }

  /// PUT /api/analysis/notes/:id
  Future<Response> _updateNotes(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString());
      await db.connection.execute(
        Sql.named('UPDATE analyses SET notes = @notes WHERE id = @id'),
        parameters: {'id': id, 'notes': body['notes'] ?? ''},
      );
      return _jsonResponse(200, {'message': 'Notas actualizadas'});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error al actualizar: $e'});
    }
  }

  /// PUT /api/analysis/feedback/:id — Guardar feedback del usuario (up/down)
  Future<Response> _updateFeedback(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final feedback = body['feedback'] as String? ?? '';
      if (feedback != 'up' && feedback != 'down') {
        return _jsonResponse(400, {'error': 'Feedback debe ser "up" o "down"'});
      }
      await db.connection.execute(
        Sql.named('UPDATE analyses SET feedback = @feedback WHERE id = @id'),
        parameters: {'id': id, 'feedback': feedback},
      );
      return _jsonResponse(200, {'message': 'Feedback guardado'});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error: $e'});
    }
  }

  /// GET /api/analysis/validated-examples — Obtener análisis validados (feedback=up) para few-shot
  Future<Response> _getValidatedExamples(Request req) async {
    try {
      // Ejemplos correctos (👍)
      final positives = await db.connection.execute(
        Sql.named('''
          SELECT caliber, ammo_type, compatible_weapon, estimated_length,
            possible_brands, confidence, description
          FROM analyses 
          WHERE feedback = 'up'
          ORDER BY created_at DESC 
          LIMIT 5
        '''),
      );

      // Ejemplos incorrectos (👎) para contra-ejemplos
      final negatives = await db.connection.execute(
        Sql.named('''
          SELECT caliber, ammo_type, compatible_weapon, estimated_length,
            possible_brands, confidence, description
          FROM analyses 
          WHERE feedback = 'down'
          ORDER BY created_at DESC 
          LIMIT 3
        '''),
      );

      final positiveExamples = positives.map((row) => {
            'caliber': row[0],
            'ammoType': row[1],
            'compatibleWeapon': row[2],
            'estimatedLength': row[3],
            'possibleBrands': row[4],
            'confidence': row[5],
            'description': row[6],
          }).toList();

      final negativeExamples = negatives.map((row) => {
            'caliber': row[0],
            'ammoType': row[1],
            'compatibleWeapon': row[2],
            'estimatedLength': row[3],
            'possibleBrands': row[4],
            'confidence': row[5],
            'description': row[6],
          }).toList();

      return _jsonResponse(200, {
        'positives': positiveExamples,
        'negatives': negativeExamples,
      });
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error: $e'});
    }
  }

  /// GET /api/analysis/stats/:userId
  Future<Response> _getStats(Request req, String userId) async {
    try {
      final result = await db.connection.execute(
        Sql.named('''
          SELECT 
            COUNT(*) as total,
            AVG(confidence) as avg_confidence,
            AVG(response_time_ms) as avg_response_time,
            COUNT(DISTINCT ai_provider) as providers_used
          FROM analyses WHERE user_id = @userId
        '''),
        parameters: {'userId': int.parse(userId)},
      );

      final row = result.first;
      return _jsonResponse(200, {
        'totalAnalyses': row[0],
        'avgConfidence': row[1],
        'avgResponseTimeMs': row[2],
        'providersUsed': row[3],
      });
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error: $e'});
    }
  }

  Response _jsonResponse(int status, Map<String, dynamic> body) {
    return Response(status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }
}

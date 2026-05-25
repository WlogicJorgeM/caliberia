import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../models/ballistic_analysis.dart';

/// Prompt de análisis balístico profesional
const String _ballisticPrompt = '''
Eres un perito experto en balística forense con 20 años de experiencia en identificación de municiones.

INSTRUCCIONES:
1. Analiza la imagen proporcionada de la evidencia balística
2. Identifica el tipo de munición, calibre, y características físicas
3. Responde ÚNICAMENTE con JSON válido, sin texto adicional

FORMATO DE RESPUESTA (JSON estricto):
{
  "caliber": "calibre específico (ej: 9x19mm Parabellum, .45 ACP, 5.56x45mm NATO, .38 Special)",
  "ammoType": "tipo de munición (ej: Full Metal Jacket, Hollow Point, Soft Point, Wadcutter, Armor Piercing)",
  "compatibleWeapon": "arma(s) compatible(s) (ej: Pistola Glock 17/19, Revólver Smith & Wesson 686)",
  "estimatedLength": "longitud total estimada en mm (ej: 29.69mm)",
  "possibleBrands": ["fabricante1", "fabricante2", "fabricante3"],
  "confidence": 0.85,
  "description": "Descripción técnica forense detallada en español. Incluir: estado de la evidencia, características del proyectil/casquillo, tipo de percusión, marcas identificativas, y observaciones relevantes para la investigación."
}

REGLAS:
- confidence: número entre 0.0 y 1.0 basado en la claridad de la imagen y certeza del análisis
- Si la imagen NO muestra munición/bala/cartucho, pon confidence: 0.1 y explica qué se observa
- Usa terminología técnica balística en español
- Sé específico: no digas "pistola" si puedes decir "pistola semiautomática calibre 9mm"
- SOLO JSON, sin markdown, sin explicaciones fuera del JSON
''';

/// Servicio de IA con soporte dual: Gemini (online) + Ollama (local)
class AIService {
  String _lastProvider = 'none';
  String get lastProvider => _lastProvider;

  /// Analiza imagen con fallback automático
  /// Orden: Gemini (si hay API key) → Ollama (local)
  Future<AnalysisResult> analyzeImage(String base64Image) async {
    final provider = _getConfiguredProvider();
    final stopwatch = Stopwatch()..start();

    try {
      BallisticResults results;

      if (provider == AIProvider.gemini || provider == AIProvider.auto) {
        try {
          results = await _analyzeWithGemini(base64Image);
          _lastProvider = 'Gemini Flash';
          stopwatch.stop();
          AppLogger.aiResponse('Gemini', stopwatch.elapsed);
          return AnalysisResult(
            results: results,
            provider: 'Gemini Flash',
            responseTime: stopwatch.elapsed,
          );
        } catch (e) {
          AppLogger.aiError('Gemini', e.toString());
          if (provider == AIProvider.gemini) rethrow;
          // Si es auto, intentar Ollama
          AppLogger.info('Fallback a Ollama...');
        }
      }

      // Ollama (local)
      results = await _analyzeWithOllama(base64Image);
      _lastProvider = 'Ollama Local';
      stopwatch.stop();
      AppLogger.aiResponse('Ollama', stopwatch.elapsed);
      return AnalysisResult(
        results: results,
        provider: 'Ollama Local',
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      if (e is AIServiceException) rethrow;
      throw AIServiceException(
        'Error en análisis de IA',
        provider: _lastProvider,
        details: e.toString(),
      );
    }
  }

  /// Verifica disponibilidad de los servicios de IA
  Future<Map<String, bool>> checkAvailability() async {
    final results = <String, bool>{};

    // Check Gemini
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    results['gemini'] = apiKey.isNotEmpty;

    // Check Ollama
    try {
      final ollamaUrl = dotenv.env['OLLAMA_URL'] ?? 'http://localhost:11434';
      final r = await http
          .get(Uri.parse('$ollamaUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      results['ollama'] = r.statusCode == 200;
    } catch (_) {
      results['ollama'] = false;
    }

    return results;
  }

  AIProvider _getConfiguredProvider() {
    final config = dotenv.env['AI_PROVIDER'] ?? 'auto';
    switch (config.toLowerCase()) {
      case 'gemini':
        return AIProvider.gemini;
      case 'ollama':
        return AIProvider.ollama;
      default:
        return AIProvider.auto;
    }
  }

  // ═══════════════════════════════════════════════════════
  // GEMINI (Google AI Studio - Gratis con visión real)
  // ═══════════════════════════════════════════════════════

  Future<BallisticResults> _analyzeWithGemini(String base64Image) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw AIUnavailableException(provider: 'Gemini');
    }

    AppLogger.aiRequest('Gemini', 'gemini-2.0-flash');

    String rawBase64 = base64Image;
    if (rawBase64.contains(',')) {
      rawBase64 = rawBase64.split(',').last;
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
        maxOutputTokens: 500,
      ),
    );

    final Uint8List imageBytes = base64Decode(rawBase64);
    final content = Content.multi([
      TextPart(_ballisticPrompt),
      DataPart('image/jpeg', imageBytes),
    ]);

    try {
      final response = await model
          .generateContent([content]).timeout(
              const Duration(seconds: AppConstants.aiTimeoutSeconds));

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw AIParseException(provider: 'Gemini', rawResponse: '');
      }

      final json = _parseJsonResponse(text, 'Gemini');
      return BallisticResults.fromJson(json);
    } on TimeoutException {
      throw AITimeoutException(provider: 'Gemini');
    }
  }

  // ═══════════════════════════════════════════════════════
  // OLLAMA (Local - Sin internet)
  // ═══════════════════════════════════════════════════════

  Future<BallisticResults> _analyzeWithOllama(String base64Image) async {
    final ollamaUrl = dotenv.env['OLLAMA_URL'] ?? 'http://localhost:11434';
    final ollamaModel = dotenv.env['OLLAMA_MODEL'] ?? 'qwen2.5-coder:1.5b';

    AppLogger.aiRequest('Ollama', ollamaModel);

    String rawBase64 = base64Image;
    if (rawBase64.contains(',')) {
      rawBase64 = rawBase64.split(',').last;
    }

    Exception? lastError;

    for (int attempt = 0; attempt < AppConstants.aiMaxRetries; attempt++) {
      try {
        if (attempt > 0) AppLogger.aiRetry('Ollama', attempt);

        final strict = attempt > 0
            ? ' ONLY JSON. No markdown. No explanations.'
            : '';

        final prompt =
            'You are a forensic ballistics expert. Analyze ammunition evidence. '
            'Reply with ONLY valid JSON:$strict\n'
            '{"caliber":"e.g. 9x19mm","ammoType":"e.g. FMJ",'
            '"compatibleWeapon":"e.g. Glock 17","estimatedLength":"e.g. 29mm",'
            '"possibleBrands":["brand1","brand2"],"confidence":0.8,'
            '"description":"Análisis forense en español, 2-3 oraciones"}';

        final body = jsonEncode({
          'model': ollamaModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': attempt == 0 ? 0.5 : 0.2,
            'num_predict': 400,
          },
        });

        final response = await http
            .post(
              Uri.parse('$ollamaUrl/api/generate'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: AppConstants.aiTimeoutSeconds));

        if (response.statusCode != 200) {
          throw AIServiceException(
            'Error HTTP ${response.statusCode}',
            provider: 'Ollama',
          );
        }

        final data = jsonDecode(response.body);
        final text = (data['response'] as String? ?? '').trim();

        if (text.isEmpty) {
          throw AIParseException(provider: 'Ollama', rawResponse: '');
        }

        final json = _parseJsonResponse(text, 'Ollama');
        return BallisticResults.fromJson(json);
      } catch (e) {
        lastError = e is Exception ? e : Exception('$e');
        if (attempt < AppConstants.aiMaxRetries - 1) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    }

    if (lastError is AIServiceException) throw lastError;
    throw AIServiceException(
      'Fallo tras ${AppConstants.aiMaxRetries} intentos',
      provider: 'Ollama',
      details: lastError.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════

  Map<String, dynamic> _parseJsonResponse(String text, String provider) {
    try {
      // Intentar parseo directo
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    // Extraer de code blocks
    final cb = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (cb != null) {
      try {
        return jsonDecode(cb.group(1)!.trim()) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Extraer JSON object
    final jm = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jm != null) {
      final candidate = jm.group(0)!;
      try {
        return jsonDecode(candidate) as Map<String, dynamic>;
      } catch (_) {
        // Intentar reparar
        final repaired = _repairJson(candidate);
        try {
          return jsonDecode(repaired) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    // JSON parcial
    final partial = RegExp(r'\{[\s\S]*').firstMatch(text);
    if (partial != null) {
      final repaired = _repairJson(partial.group(0)!);
      try {
        return jsonDecode(repaired) as Map<String, dynamic>;
      } catch (_) {}
    }

    throw AIParseException(provider: provider, rawResponse: text);
  }

  String _repairJson(String text) {
    var s = text.trim();
    s = s.replaceAll(RegExp(r',\s*}'), '}');
    s = s.replaceAll(RegExp(r',\s*]'), ']');

    int braces = 0, brackets = 0;
    bool inString = false;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '"' && (i == 0 || s[i - 1] != '\\')) inString = !inString;
      if (!inString) {
        if (s[i] == '{') braces++;
        if (s[i] == '}') braces--;
        if (s[i] == '[') brackets++;
        if (s[i] == ']') brackets--;
      }
    }
    if (inString) s += '"';
    for (int i = 0; i < brackets; i++) s += ']';
    for (int i = 0; i < braces; i++) s += '}';
    return s;
  }
}

/// Resultado del análisis con metadatos
class AnalysisResult {
  final BallisticResults results;
  final String provider;
  final Duration responseTime;

  AnalysisResult({
    required this.results,
    required this.provider,
    required this.responseTime,
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../models/ballistic_analysis.dart';
import 'backend_service.dart';
import 'knowledge_base.dart';

/// Prompt de análisis balístico profesional
const String _ballisticPrompt = '''
Analyze this ammunition/bullet image. Identify caliber, type, and weapon.
Reply with ONE JSON object only:
{"caliber":"specific caliber","ammoType":"ammo type","compatibleWeapon":"weapon","estimatedLength":"mm","possibleBrands":["brand1","brand2"],"confidence":0.85,"description":"Technical forensic description in Spanish"}
Rules: confidence 0-1, description in Spanish, if not ammo set confidence 0.1. JSON only.
''';

/// Servicio de IA con Groq (visión real, gratis, rápido)
/// Implementa few-shot learning con ejemplos validados por usuarios
class AIService {
  String _lastProvider = 'none';
  String get lastProvider => _lastProvider;

  /// Knowledge Base para matching de imágenes similares
  final KnowledgeBase knowledgeBase = KnowledgeBase();
  
  /// Ejemplos validados por usuarios (few-shot)
  List<Map<String, dynamic>> _positiveExamples = [];
  List<Map<String, dynamic>> _negativeExamples = [];

  /// Agregar ejemplo negativo localmente (sin esperar al backend)
  void addLocalNegative(Map<String, dynamic> example) {
    _negativeExamples.insert(0, example);
    if (_negativeExamples.length > 5) _negativeExamples.removeLast();
    AppLogger.info('Ejemplo negativo agregado al cache local');
  }

  /// Agregar ejemplo positivo localmente
  void addLocalPositive(Map<String, dynamic> example) {
    _positiveExamples.insert(0, example);
    if (_positiveExamples.length > 5) _positiveExamples.removeLast();
    AppLogger.info('Ejemplo positivo agregado al cache local');
  }

  /// Cargar ejemplos validados del backend
  Future<void> loadValidatedExamples() async {
    try {
      final data = await BackendService.getValidatedExamples();
      final backendPositives = data['positives'] ?? [];
      final backendNegatives = data['negatives'] ?? [];
      // Merge con locales (locales tienen prioridad por ser más recientes)
      for (final p in backendPositives) {
        if (!_positiveExamples.any((e) => e['caliber'] == p['caliber'] && e['description'] == p['description'])) {
          _positiveExamples.add(p);
        }
      }
      for (final n in backendNegatives) {
        if (!_negativeExamples.any((e) => e['caliber'] == n['caliber'] && e['description'] == n['description'])) {
          _negativeExamples.add(n);
        }
      }
      if (_positiveExamples.isNotEmpty || _negativeExamples.isNotEmpty) {
        AppLogger.info(
            'Few-shot: ${_positiveExamples.length} positivos, ${_negativeExamples.length} negativos');
      }
    } catch (_) {}
  }

  /// Analiza imagen — La IA SIEMPRE interpreta.
  /// Solo usa Knowledge Base para match EXACTO (misma imagen ya validada).
  Future<AnalysisResult> analyzeImage(String base64Image) async {
    final stopwatch = Stopwatch()..start();
    final provider = _getConfiguredProvider();

    // ═══ PASO 1: Solo match EXACTO (misma imagen, mismo hash) ═══
    final match = knowledgeBase.findExactMatch(base64Image);
    if (match != null) {
      stopwatch.stop();
      _lastProvider = 'Validado (imagen idéntica)';
      AppLogger.info('✅ Match EXACTO en Knowledge Base');
      return AnalysisResult(
        results: match.results,
        provider: 'Validado (imagen idéntica)',
        responseTime: stopwatch.elapsed,
      );
    }

    // ═══ PASO 2: La IA SIEMPRE interpreta ═══
    try {
      BallisticResults results;

      if (provider == AIProvider.groq || provider == AIProvider.auto) {
        try {
          results = await _analyzeWithGroq(base64Image);
          _lastProvider = 'Groq (Llama 4 Scout)';
          stopwatch.stop();
          AppLogger.aiResponse('Groq', stopwatch.elapsed);
          return AnalysisResult(
            results: results,
            provider: 'Groq (Llama 4 Scout)',
            responseTime: stopwatch.elapsed,
          );
        } catch (e) {
          AppLogger.aiError('Groq', e.toString());
          if (provider == AIProvider.groq) rethrow;
          AppLogger.info('Fallback a Ollama...');
        }
      }

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

  /// Verifica disponibilidad
  Future<Map<String, bool>> checkAvailability() async {
    final results = <String, bool>{};

    // Check Groq
    final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';
    results['groq'] = groqKey.isNotEmpty;

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
      case 'groq':
        return AIProvider.groq;
      case 'ollama':
        return AIProvider.ollama;
      default:
        return AIProvider.auto;
    }
  }

  // ═══════════════════════════════════════════════════════
  // GROQ (Gratis, con visión REAL, ultra rápido)
  // ═══════════════════════════════════════════════════════

  Future<BallisticResults> _analyzeWithGroq(String base64Image) async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw AIUnavailableException(provider: 'Groq');
    }

    AppLogger.aiRequest('Groq', 'llama-4-scout-17b-16e-instruct');

    String rawBase64 = base64Image;
    if (rawBase64.contains(',')) {
      rawBase64 = rawBase64.split(',').last;
    }

    // Log tamaño de imagen
    final imageSizeKB = (rawBase64.length * 3 / 4) ~/ 1024;
    AppLogger.info('Imagen: ${imageSizeKB}KB base64');
    
    // Si la imagen es muy grande (>3MB en base64), Groq la rechaza
    if (rawBase64.length > 4000000) {
      AppLogger.warning('Imagen demasiado grande para Groq (>${imageSizeKB}KB)');
      throw AIServiceException('Imagen demasiado grande (max 3MB)', provider: 'Groq');
    }

    // Construir prompt con few-shot si hay ejemplos validados
    String fewShotSection = '';
    if (_negativeExamples.isNotEmpty) {
      fewShotSection += '\n\n⚠️ IMPORTANTE - RESPUESTAS RECHAZADAS POR EL USUARIO:\n';
      fewShotSection += 'Las siguientes respuestas fueron marcadas como INCORRECTAS. NO repitas estos resultados:\n';
      for (int i = 0; i < _negativeExamples.length && i < 5; i++) {
        fewShotSection += '❌ INCORRECTO: ${jsonEncode(_negativeExamples[i])}\n';
      }
      fewShotSection += '\nDEBES dar una respuesta DIFERENTE a las anteriores. Analiza la imagen con más cuidado.\n';
    }
    if (_positiveExamples.isNotEmpty) {
      fewShotSection += '\n✅ EJEMPLOS CORRECTOS (validados por expertos):\n';
      for (int i = 0; i < _positiveExamples.length && i < 3; i++) {
        fewShotSection += '${jsonEncode(_positiveExamples[i])}\n';
      }
      fewShotSection += 'Usa el nivel de detalle y precisión de estos ejemplos.\n';
    }

    final fullPrompt = _ballisticPrompt + fewShotSection;

    final body = jsonEncode({
      'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': fullPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$rawBase64',
              },
            },
          ],
        }
      ],
      // Subir temperatura para generar respuestas variadas + seed aleatorio
      'temperature': _negativeExamples.isNotEmpty ? 0.8 : 0.5,
      'max_completion_tokens': 600,
      'stream': false,
      'seed': DateTime.now().millisecondsSinceEpoch % 100000,
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: AppConstants.aiTimeoutSeconds));

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body);
        throw AIServiceException(
          err['error']?['message'] ?? 'Error ${response.statusCode}',
          provider: 'Groq',
        );
      }

      final data = jsonDecode(response.body);
      final text =
          data['choices'][0]['message']['content'] as String? ?? '';

      if (text.isEmpty) {
        throw AIParseException(provider: 'Groq', rawResponse: '');
      }

      final json = _parseJsonResponse(text, 'Groq');
      return BallisticResults.fromJson(json);
    } on TimeoutException {
      throw AITimeoutException(provider: 'Groq');
    }
  }

  // ═══════════════════════════════════════════════════════
  // OLLAMA (Local fallback)
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
    final cleaned = text.trim();
    
    // 1. Intentar parseo directo como objeto
    try {
      final result = jsonDecode(cleaned);
      if (result is Map<String, dynamic>) return result;
      // Si es un array, tomar el primer elemento
      if (result is List && result.isNotEmpty && result[0] is Map<String, dynamic>) {
        return result[0] as Map<String, dynamic>;
      }
    } catch (_) {}

    // 2. Buscar en code blocks
    final cb = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(cleaned);
    if (cb != null) {
      try {
        final inner = jsonDecode(cb.group(1)!.trim());
        if (inner is Map<String, dynamic>) return inner;
        if (inner is List && inner.isNotEmpty) return inner[0] as Map<String, dynamic>;
      } catch (_) {}
    }

    // 3. Buscar array de objetos JSON
    final arrMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
    if (arrMatch != null) {
      try {
        final arr = jsonDecode(arrMatch.group(0)!);
        if (arr is List && arr.isNotEmpty && arr[0] is Map<String, dynamic>) {
          return arr[0] as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    // 4. Buscar primer JSON object
    final jm = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').firstMatch(cleaned);
    if (jm != null) {
      try {
        return jsonDecode(jm.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        final repaired = _repairJson(jm.group(0)!);
        try {
          return jsonDecode(repaired) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    // 5. Buscar cualquier { y reparar
    final partial = RegExp(r'\{[\s\S]*').firstMatch(cleaned);
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

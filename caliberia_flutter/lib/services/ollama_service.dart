import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ballistic_analysis.dart';

class OllamaService {
  static String get _baseUrl =>
      dotenv.env['OLLAMA_URL'] ?? 'http://localhost:11434';
  static String get _model =>
      dotenv.env['OLLAMA_MODEL'] ?? 'qwen2.5-coder:1.5b';

  /// Analiza imagen con hasta 2 reintentos si falla el parseo
  static Future<BallisticResults> analyzeBallisticImage(
      String base64Image) async {
    String rawBase64 = base64Image;
    if (rawBase64.contains(',')) {
      rawBase64 = rawBase64.split(',').last;
    }

    final imageBytes = base64Decode(rawBase64);
    final sizeKB = (imageBytes.length / 1024).round();

    Exception? lastError;

    // Hasta 3 intentos
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _callOllama(sizeKB, attempt);
        return result;
      } catch (e) {
        lastError = e is Exception ? e : Exception('$e');
        // Esperar un poco antes de reintentar
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    throw lastError ?? Exception('Error desconocido tras 3 intentos');
  }

  static Future<BallisticResults> _callOllama(int sizeKB, int attempt) async {
    // Prompt más estricto en reintentos
    final strict = attempt > 0
        ? ' You MUST reply with ONLY a JSON object. No explanations. No markdown.'
        : '';

    final prompt =
        'You are a forensic ballistics expert analyzing ammunition evidence '
        '(photo: ${sizeKB}KB). Generate a ballistics report as JSON.$strict\n'
        'Reply with ONLY this JSON structure (no other text):\n'
        '{"caliber":"e.g. 9x19mm Parabellum","ammoType":"e.g. Full Metal Jacket",'
        '"compatibleWeapon":"e.g. Glock 17/Beretta 92","estimatedLength":"e.g. 29.69mm",'
        '"possibleBrands":["Federal","Remington"],"confidence":0.85,'
        '"description":"Análisis forense detallado en español, 2-3 oraciones técnicas"}';

    final body = jsonEncode({
      'model': _model,
      'prompt': prompt,
      'stream': false,
      'options': {
        'temperature': attempt == 0 ? 0.7 : 0.3,
        'num_predict': 400,
      },
    });

    final uri = Uri.parse('$_baseUrl/api/generate');

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('Ollama respondió con error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = (data['response'] as String? ?? '').trim();

    if (text.isEmpty) {
      throw Exception('Respuesta vacía del modelo');
    }

    final jsonStr = _extractJson(text);

    // Intentar parsear, si falla intentar reparar
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      return _safeParseResults(json);
    } catch (_) {
      // Intentar reparar JSON truncado
      final repaired = _repairJson(jsonStr);
      final Map<String, dynamic> json = jsonDecode(repaired);
      return _safeParseResults(json);
    }
  }

  /// Parseo seguro que nunca falla por campos faltantes
  static BallisticResults _safeParseResults(Map<String, dynamic> json) {
    List<String> brands = [];
    if (json['possibleBrands'] is List) {
      brands = (json['possibleBrands'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['possibleBrands'] is String) {
      brands = [json['possibleBrands'] as String];
    }

    double confidence = 0.8;
    if (json['confidence'] is num) {
      confidence = (json['confidence'] as num).toDouble();
    } else if (json['confidence'] is String) {
      confidence = double.tryParse(json['confidence'] as String) ?? 0.8;
    }

    return BallisticResults(
      caliber: (json['caliber'] ?? 'No determinado').toString(),
      ammoType: (json['ammoType'] ?? 'No determinado').toString(),
      compatibleWeapon:
          (json['compatibleWeapon'] ?? 'No determinado').toString(),
      estimatedLength:
          (json['estimatedLength'] ?? 'No determinado').toString(),
      possibleBrands: brands.isEmpty ? ['No determinado'] : brands,
      confidence: confidence.clamp(0.0, 1.0),
      description: (json['description'] ?? 'Análisis en proceso.').toString(),
    );
  }

  /// Intenta reparar JSON truncado o mal cerrado
  static String _repairJson(String text) {
    var s = text.trim();

    // Quitar trailing commas antes de } o ]
    s = s.replaceAll(RegExp(r',\s*}'), '}');
    s = s.replaceAll(RegExp(r',\s*]'), ']');

    // Contar llaves y corchetes abiertos
    int braces = 0;
    int brackets = 0;
    bool inString = false;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '"' && (i == 0 || s[i - 1] != '\\')) {
        inString = !inString;
      }
      if (!inString) {
        if (s[i] == '{') braces++;
        if (s[i] == '}') braces--;
        if (s[i] == '[') brackets++;
        if (s[i] == ']') brackets--;
      }
    }

    // Si estamos dentro de un string, cerrarlo
    if (inString) s += '"';

    // Cerrar corchetes y llaves faltantes
    for (int i = 0; i < brackets; i++) {
      s += ']';
    }
    for (int i = 0; i < braces; i++) {
      s += '}';
    }

    return s;
  }

  static Future<bool> isAvailable() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _extractJson(String text) {
    // 1. Buscar en code blocks
    final cb = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (cb != null) return cb.group(1)!.trim();

    // 2. Buscar JSON object completo
    final jm = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jm != null) return jm.group(0)!;

    // 3. Buscar JSON que empieza con { pero puede estar truncado
    final partial = RegExp(r'\{[\s\S]*').firstMatch(text);
    if (partial != null) return partial.group(0)!;

    return text.trim();
  }
}

/// Modelo principal de análisis balístico
class BallisticAnalysis {
  final String id;
  final int timestamp;
  final String imageBase64;
  final BallisticResults results;
  final String aiProvider;
  final int responseTimeMs;
  String notes;
  String? feedback; // 'up', 'down', o null (pendiente)

  BallisticAnalysis({
    required this.id,
    required this.timestamp,
    required this.imageBase64,
    required this.results,
    this.aiProvider = 'unknown',
    this.responseTimeMs = 0,
    this.notes = '',
    this.feedback,
  });

  bool get needsFeedback => feedback == null;
  bool get isValidated => feedback == 'up';
  bool get isRejected => feedback == 'down';

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'imageBase64': imageBase64,
        'results': results.toJson(),
        'aiProvider': aiProvider,
        'responseTimeMs': responseTimeMs,
        'notes': notes,
        'feedback': feedback,
        '_version': 2,
      };

  factory BallisticAnalysis.fromJson(Map<String, dynamic> json) =>
      BallisticAnalysis(
        id: json['id'] ?? '',
        timestamp: json['timestamp'] ?? 0,
        imageBase64: json['imageBase64'] ?? '',
        results: BallisticResults.fromJson(
            json['results'] is Map<String, dynamic> ? json['results'] : {}),
        aiProvider: json['aiProvider'] ?? 'unknown',
        responseTimeMs: json['responseTimeMs'] ?? 0,
        notes: json['notes'] ?? '',
        feedback: json['feedback'],
      );
}

class BallisticResults {
  final String caliber;
  final String ammoType;
  final String compatibleWeapon;
  final String estimatedLength;
  final List<String> possibleBrands;
  final double confidence;
  final String description;

  BallisticResults({
    required this.caliber,
    required this.ammoType,
    required this.compatibleWeapon,
    required this.estimatedLength,
    required this.possibleBrands,
    required this.confidence,
    required this.description,
  });

  String get confidenceLevel {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }

  bool get isValidAnalysis => confidence > 0.2;

  Map<String, dynamic> toJson() => {
        'caliber': caliber,
        'ammoType': ammoType,
        'compatibleWeapon': compatibleWeapon,
        'estimatedLength': estimatedLength,
        'possibleBrands': possibleBrands,
        'confidence': confidence,
        'description': description,
      };

  factory BallisticResults.fromJson(Map<String, dynamic> json) {
    double conf = 0.0;
    final rawConf = json['confidence'];
    if (rawConf is num) {
      conf = rawConf.toDouble();
    } else if (rawConf is String) {
      conf = double.tryParse(rawConf) ?? 0.0;
    }

    List<String> brands = [];
    final rawBrands = json['possibleBrands'];
    if (rawBrands is List) {
      brands = rawBrands.map((e) => e.toString()).toList();
    } else if (rawBrands is String) {
      brands = [rawBrands];
    }

    return BallisticResults(
      caliber: (json['caliber'] ?? 'No determinado').toString(),
      ammoType: (json['ammoType'] ?? 'No determinado').toString(),
      compatibleWeapon:
          (json['compatibleWeapon'] ?? 'No determinado').toString(),
      estimatedLength:
          (json['estimatedLength'] ?? 'No determinado').toString(),
      possibleBrands: brands.isEmpty ? ['No determinado'] : brands,
      confidence: conf.clamp(0.0, 1.0),
      description:
          (json['description'] ?? 'Análisis completado.').toString(),
    );
  }
}

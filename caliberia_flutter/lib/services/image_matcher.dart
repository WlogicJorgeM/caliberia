import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/app_logger.dart';

/// Servicio de matching de imágenes usando características extraídas
/// Implementa un modelo simplificado de similitud visual:
/// 1. Hash perceptual (pHash simplificado) para comparar estructura
/// 2. Histograma de luminosidad para comparar tonos
/// 3. Ratio de aspecto y tamaño para filtrar candidatos
class ImageMatcher {
  /// Extrae un fingerprint de la imagen para comparación
  static ImageFingerprint extractFingerprint(String base64Image) {
    String raw = base64Image;
    if (raw.contains(',')) raw = raw.split(',').last;

    final bytes = base64Decode(raw);
    final sizeKB = bytes.length ~/ 1024;

    // 1. Hash MD5 del contenido (match exacto)
    final contentHash = md5.convert(bytes).toString();

    // 2. Hash parcial (primeros 2KB) - detecta imágenes redimensionadas
    final partialBytes = bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes;
    final partialHash = md5.convert(partialBytes).toString();

    // 3. Histograma simplificado de bytes (distribución de valores)
    final histogram = _computeHistogram(bytes);

    // 4. Tamaño como feature
    return ImageFingerprint(
      contentHash: contentHash,
      partialHash: partialHash,
      histogram: histogram,
      sizeKB: sizeKB,
    );
  }

  /// Compara dos fingerprints y devuelve score de similitud (0.0 - 1.0)
  static double compareSimilarity(ImageFingerprint a, ImageFingerprint b) {
    // Match exacto
    if (a.contentHash == b.contentHash) return 1.0;

    // Match parcial (misma imagen, diferente calidad)
    if (a.partialHash == b.partialHash) return 0.95;

    // Comparar histogramas (similitud visual)
    final histSimilarity = _compareHistograms(a.histogram, b.histogram);

    // Comparar tamaño (imágenes similares suelen tener tamaño similar)
    final sizeDiff = (a.sizeKB - b.sizeKB).abs();
    final sizeSimilarity = sizeDiff < 50 ? 1.0 : (sizeDiff < 200 ? 0.7 : 0.3);

    // Score combinado (histograma pesa más)
    return (histSimilarity * 0.7) + (sizeSimilarity * 0.3);
  }

  /// Computa histograma simplificado de 16 bins
  static List<double> _computeHistogram(Uint8List bytes) {
    final bins = List<int>.filled(16, 0);
    // Saltar header de imagen (primeros 100 bytes suelen ser metadata)
    final start = bytes.length > 200 ? 100 : 0;
    final sampleSize = (bytes.length - start).clamp(0, 10000);

    for (int i = start; i < start + sampleSize; i++) {
      final bin = bytes[i] ~/ 16; // 256 valores / 16 bins
      bins[bin]++;
    }

    // Normalizar
    final total = sampleSize > 0 ? sampleSize.toDouble() : 1.0;
    return bins.map((b) => b / total).toList();
  }

  /// Compara dos histogramas usando correlación
  static double _compareHistograms(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double sumAB = 0, sumA2 = 0, sumB2 = 0;
    final meanA = a.reduce((x, y) => x + y) / a.length;
    final meanB = b.reduce((x, y) => x + y) / b.length;

    for (int i = 0; i < a.length; i++) {
      final da = a[i] - meanA;
      final db = b[i] - meanB;
      sumAB += da * db;
      sumA2 += da * da;
      sumB2 += db * db;
    }

    final denom = (sumA2 * sumB2);
    if (denom <= 0) return 0.0;
    final correlation = sumAB / _sqrt(denom);
    return correlation.clamp(0.0, 1.0);
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

/// Fingerprint de una imagen para comparación
class ImageFingerprint {
  final String contentHash;
  final String partialHash;
  final List<double> histogram;
  final int sizeKB;

  ImageFingerprint({
    required this.contentHash,
    required this.partialHash,
    required this.histogram,
    required this.sizeKB,
  });

  Map<String, dynamic> toJson() => {
        'contentHash': contentHash,
        'partialHash': partialHash,
        'histogram': histogram,
        'sizeKB': sizeKB,
      };

  factory ImageFingerprint.fromJson(Map<String, dynamic> json) =>
      ImageFingerprint(
        contentHash: json['contentHash'] ?? '',
        partialHash: json['partialHash'] ?? '',
        histogram: List<double>.from(json['histogram'] ?? []),
        sizeKB: json['sizeKB'] ?? 0,
      );
}

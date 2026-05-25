import '../core/app_logger.dart';
import '../models/ballistic_analysis.dart';
import 'image_matcher.dart';
import 'storage_service.dart';

/// Base de conocimiento local que almacena análisis validados
/// y permite buscar por similitud de imagen
class KnowledgeBase {
  /// Análisis validados con sus fingerprints
  final List<_KnowledgeEntry> _entries = [];

  /// Umbral de similitud para considerar un match (0.0 - 1.0)
  static const double matchThreshold = 0.75;

  /// Cargar conocimiento desde el historial local
  Future<void> loadFromHistory() async {
    final history = await StorageService.getHistory();
    _entries.clear();

    for (final analysis in history) {
      if (analysis.feedback == 'up') {
        final fp = ImageMatcher.extractFingerprint(analysis.imageBase64);
        _entries.add(_KnowledgeEntry(
          fingerprint: fp,
          results: analysis.results,
          aiProvider: 'Knowledge Base',
        ));
      }
    }

    if (_entries.isNotEmpty) {
      AppLogger.info(
          'Knowledge Base: ${_entries.length} análisis validados cargados');
    }
  }

  /// Agregar un análisis validado a la base de conocimiento
  void addValidated(BallisticAnalysis analysis) {
    final fp = ImageMatcher.extractFingerprint(analysis.imageBase64);
    _entries.add(_KnowledgeEntry(
      fingerprint: fp,
      results: analysis.results,
      aiProvider: analysis.aiProvider,
    ));
    AppLogger.info(
        'Knowledge Base: nuevo análisis validado agregado (total: ${_entries.length})');
  }

  /// Remover análisis rechazados de la base (por hash exacto o parcial)
  void removeRejected(BallisticAnalysis analysis) {
    final fp = ImageMatcher.extractFingerprint(analysis.imageBase64);
    _entries.removeWhere((e) =>
        e.fingerprint.contentHash == fp.contentHash ||
        e.fingerprint.partialHash == fp.partialHash);
    AppLogger.info('Knowledge Base: entrada removida (total: ${_entries.length})');
  }

  /// Buscar SOLO match exacto (misma imagen, mismo hash MD5)
  /// Retorna resultado solo si es la MISMA imagen ya validada
  MatchResult? findExactMatch(String base64Image) {
    if (_entries.isEmpty) return null;

    final queryFp = ImageMatcher.extractFingerprint(base64Image);

    for (final entry in _entries) {
      if (entry.fingerprint.contentHash == queryFp.contentHash) {
        AppLogger.info('Knowledge Base: Match EXACTO encontrado (mismo hash)');
        return MatchResult(
          results: entry.results,
          similarity: 1.0,
          source: 'Imagen idéntica validada',
        );
      }
    }

    return null;
  }

  /// Buscar si hay un análisis similar validado (para referencia, no para reemplazar IA)
  MatchResult? findMatch(String base64Image) {
    if (_entries.isEmpty) return null;

    final queryFp = ImageMatcher.extractFingerprint(base64Image);

    double bestScore = 0.0;
    _KnowledgeEntry? bestMatch;

    for (final entry in _entries) {
      final score =
          ImageMatcher.compareSimilarity(queryFp, entry.fingerprint);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry;
      }
    }

    if (bestScore >= matchThreshold && bestMatch != null) {
      AppLogger.info(
          'Knowledge Base: Match encontrado (similitud: ${(bestScore * 100).toStringAsFixed(1)}%)');
      return MatchResult(
        results: bestMatch.results,
        similarity: bestScore,
        source: bestScore >= 0.95
            ? 'Imagen idéntica validada'
            : 'Imagen similar validada (${(bestScore * 100).toStringAsFixed(0)}%)',
      );
    }

    AppLogger.debug(
        'Knowledge Base: Sin match (mejor: ${(bestScore * 100).toStringAsFixed(1)}%)');
    return null;
  }

  int get size => _entries.length;
  bool get isEmpty => _entries.isEmpty;
}

class _KnowledgeEntry {
  final ImageFingerprint fingerprint;
  final BallisticResults results;
  final String aiProvider;

  _KnowledgeEntry({
    required this.fingerprint,
    required this.results,
    required this.aiProvider,
  });
}

/// Resultado de un match en la base de conocimiento
class MatchResult {
  final BallisticResults results;
  final double similarity;
  final String source;

  MatchResult({
    required this.results,
    required this.similarity,
    required this.source,
  });
}

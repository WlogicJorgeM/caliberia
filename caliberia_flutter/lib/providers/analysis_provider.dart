import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/app_logger.dart';
import '../models/ballistic_analysis.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/backend_service.dart';

enum AnalysisState { idle, analyzing, success, error }

class AnalysisProvider extends ChangeNotifier {
  final AIService _aiService = AIService();

  AnalysisState _state = AnalysisState.idle;
  List<BallisticAnalysis> _history = [];
  BallisticAnalysis? _currentAnalysis;
  String? _error;
  String _lastProvider = '';
  Duration _lastResponseTime = Duration.zero;
  Map<String, bool> _aiAvailability = {};

  // Getters
  AnalysisState get state => _state;
  List<BallisticAnalysis> get history => _history;
  BallisticAnalysis? get currentAnalysis => _currentAnalysis;
  String? get error => _error;
  String get lastProvider => _lastProvider;
  Duration get lastResponseTime => _lastResponseTime;
  Map<String, bool> get aiAvailability => _aiAvailability;
  bool get isAnalyzing => _state == AnalysisState.analyzing;

  /// Inicializar: cargar historial y verificar IA
  Future<void> initialize() async {
    // Intentar cargar del backend primero, luego local
    final backendHistory = await BackendService.getHistory();
    if (backendHistory != null && backendHistory.isNotEmpty) {
      _history = backendHistory;
      AppLogger.info('Historial cargado desde PostgreSQL');
    } else {
      _history = await StorageService.getHistory();
      AppLogger.info('Historial cargado desde almacenamiento local');
    }
    _aiAvailability = await _aiService.checkAvailability();
    // Cargar Knowledge Base con análisis validados
    await _aiService.knowledgeBase.loadFromHistory();
    // Cargar ejemplos para few-shot
    await _aiService.loadValidatedExamples();
    AppLogger.info(
        'IA disponible: Groq=${_aiAvailability['groq']}, Ollama=${_aiAvailability['ollama']}');
    AppLogger.info('Knowledge Base: ${_aiService.knowledgeBase.size} entradas');
    notifyListeners();
  }

  /// Verificar disponibilidad de IA
  Future<void> refreshAvailability() async {
    _aiAvailability = await _aiService.checkAvailability();
    notifyListeners();
  }

  /// Analizar imagen
  Future<void> analyzeImage(String base64Image) async {
    _state = AnalysisState.analyzing;
    _error = null;
    _currentAnalysis = null;
    notifyListeners();

    try {
      final result = await _aiService.analyzeImage(base64Image);

      final analysis = BallisticAnalysis(
        id: _generateId(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        imageBase64: base64Image,
        results: result.results,
        aiProvider: result.provider,
        responseTimeMs: result.responseTime.inMilliseconds,
      );

      _currentAnalysis = analysis;
      _lastProvider = result.provider;
      _lastResponseTime = result.responseTime;
      _state = AnalysisState.success;

      // Guardar en historial local + backend
      _history.insert(0, analysis);
      await StorageService.saveHistory(_history);
      // Guardar en PostgreSQL (async, no bloquea)
      BackendService.saveAnalysis(analysis);

      AppLogger.info(
          'Análisis completado: ${result.provider} en ${result.responseTime.inSeconds}s');
    } catch (e) {
      _state = AnalysisState.error;
      _error = e.toString();
      AppLogger.error('Error en análisis', e);
    }

    notifyListeners();
  }

  /// Seleccionar análisis del historial
  void selectAnalysis(BallisticAnalysis analysis) {
    _currentAnalysis = analysis;
    _state = AnalysisState.success;
    notifyListeners();
  }

  /// Guardar notas
  Future<void> saveNotes(String id, String notes) async {
    final idx = _history.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _history[idx].notes = notes;
      if (_currentAnalysis?.id == id) {
        _currentAnalysis!.notes = notes;
      }
      await StorageService.saveHistory(_history);
      BackendService.updateNotes(id, notes);
      notifyListeners();
    }
  }

  /// Eliminar del historial
  Future<void> deleteAnalysis(String id) async {
    _history.removeWhere((e) => e.id == id);
    if (_currentAnalysis?.id == id) {
      _currentAnalysis = null;
      _state = AnalysisState.idle;
    }
    await StorageService.saveHistory(_history);
    BackendService.deleteAnalysis(id);
    notifyListeners();
  }

  /// Volver al estado inicial
  void reset() {
    _state = AnalysisState.idle;
    _currentAnalysis = null;
    _error = null;
    notifyListeners();
  }

  /// Enviar feedback (👍/👎) para un análisis
  Future<void> sendFeedback(String id, String feedback) async {
    final idx = _history.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _history[idx].feedback = feedback;
      if (_currentAnalysis?.id == id) {
        _currentAnalysis!.feedback = feedback;
      }
      await StorageService.saveHistory(_history);
      BackendService.sendFeedback(id, feedback);

      // Actualizar Knowledge Base según feedback
      if (feedback == 'up') {
        // 👍 → Agregar a la base de conocimiento para futuros matches
        _aiService.knowledgeBase.addValidated(_history[idx]);
        _aiService.addLocalPositive(_history[idx].results.toJson());
      } else {
        // 👎 → Remover de la base si estaba, agregar como negativo
        _aiService.knowledgeBase.removeRejected(_history[idx]);
        _aiService.addLocalNegative(_history[idx].results.toJson());
      }

      // Recargar ejemplos del backend
      await _aiService.loadValidatedExamples();
      notifyListeners();
    }
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
}

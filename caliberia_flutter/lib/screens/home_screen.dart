import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models/ballistic_analysis.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';
import '../widgets/analysis_result_widget.dart';
import '../widgets/history_list_widget.dart';

class HomeScreen extends StatefulWidget {
  final String user;
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.user, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AppView { home, analysis, history }

class _HomeScreenState extends State<HomeScreen> {
  AppView _view = AppView.home;
  List<BallisticAnalysis> _history = [];
  bool _isAnalyzing = false;
  BallisticAnalysis? _currentAnalysis;
  String? _error;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.getHistory();
    setState(() => _history = history);
  }

  Future<void> _saveHistory() async {
    await StorageService.saveHistory(_history);
  }

  Future<void> _captureImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() {
      _isAnalyzing = true;
      _currentAnalysis = null;
      _error = null;
      _view = AppView.analysis;
    });

    try {
      final results = await OllamaService.analyzeBallisticImage(base64);
      final analysis = BallisticAnalysis(
        id: Random().nextInt(999999999).toRadixString(36),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        imageBase64: base64,
        results: results,
      );
      setState(() {
        _isAnalyzing = false;
        _currentAnalysis = analysis;
        _history.insert(0, analysis);
      });
      _saveHistory();
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _error = 'Error: $e';
      });
    }
  }

  void _onSaveNotes(String notes) {
    if (_currentAnalysis == null) return;
    setState(() {
      _currentAnalysis!.notes = notes;
      final idx = _history.indexWhere((e) => e.id == _currentAnalysis!.id);
      if (idx != -1) _history[idx] = _currentAnalysis!;
    });
    _saveHistory();
  }

  void _onDeleteHistory(String id) {
    setState(() {
      _history.removeWhere((e) => e.id == id);
      if (_currentAnalysis?.id == id) {
        _currentAnalysis = null;
        _view = AppView.home;
      }
    });
    _saveHistory();
  }

  void _onSelectHistory(BallisticAnalysis item) {
    setState(() {
      _currentAnalysis = item;
      _isAnalyzing = false;
      _error = null;
      _view = AppView.analysis;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final agentName = widget.user.split('@').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.zinc950,
        border: Border(bottom: BorderSide(color: AppColors.zinc900)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emerald500,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald500.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.shield, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CaliberIA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Agente: $agentName',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.emerald500,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_view != AppView.home)
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.zinc400),
              onPressed: () => setState(() => _view = AppView.home),
            ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: _view == AppView.history
                  ? AppColors.emerald500
                  : AppColors.zinc400,
            ),
            onPressed: () => setState(() => _view = AppView.history),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.zinc600, size: 20),
            onPressed: widget.onLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case AppView.home:
        return _buildHomeView();
      case AppView.analysis:
        return _buildAnalysisView();
      case AppView.history:
        return _buildHistoryView();
    }
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // New Analysis Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.zinc900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.zinc800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.biotech, color: AppColors.emerald500, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Nuevo Análisis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Capture o suba una imagen de alta resolución de la munición para iniciar el procesamiento balístico automatizado.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.zinc400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _CaptureButton(
                        icon: Icons.camera_alt,
                        label: 'Cámara',
                        onTap: () => _captureImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CaptureButton(
                        icon: Icons.photo_library,
                        label: 'Galería',
                        onTap: () => _captureImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.zinc900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.zinc800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storage, size: 20, color: AppColors.zinc500),
                      const SizedBox(height: 8),
                      Text(
                        '${_history.length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'REGISTROS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.zinc500,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.zinc900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.zinc800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.zinc500),
                      const SizedBox(height: 8),
                      const Text(
                        'Modelo entrenado para calibres comunes y marcas globales.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.zinc400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => setState(() => _view = AppView.home),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 18, color: AppColors.zinc500),
                SizedBox(width: 4),
                Text('Volver',
                    style: TextStyle(color: AppColors.zinc500, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_isAnalyzing)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (_currentAnalysis != null)
            AnalysisResultWidget(
              analysis: _currentAnalysis!,
              onSaveNotes: _onSaveNotes,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.emerald500,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Procesando Evidencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Analizando patrones balísticos...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.zinc500,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.red500.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.red500.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield, size: 48, color: AppColors.red500),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _view = AppView.home),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reintentar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial Forense',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _view = AppView.home),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: AppColors.zinc500, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: HistoryListWidget(
              history: _history,
              onSelect: _onSelectHistory,
              onDelete: _onDeleteHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.zinc900)),
      ),
      child: const Text(
        'CALIBERIA V1.0.0 // INVESTIGACIÓN ACADÉMICA // 2026',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          color: AppColors.zinc600,
          fontFamily: 'monospace',
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.zinc800, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.zinc400),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.zinc400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

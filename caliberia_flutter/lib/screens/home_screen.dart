import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../core/constants.dart';
import '../models/ballistic_analysis.dart';
import '../providers/analysis_provider.dart';
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
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Inicializar provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalysisProvider>().initialize();
    });
  }

  Future<void> _captureImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: AppConstants.maxImageWidth.toDouble(),
      imageQuality: AppConstants.imageQuality,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() => _view = AppView.analysis);
    if (!mounted) return;
    context.read<AnalysisProvider>().analyzeImage(base64);
  }

  void _onSelectHistory(BallisticAnalysis item) {
    context.read<AnalysisProvider>().selectAnalysis(item);
    setState(() => _view = AppView.analysis);
  }

  void _onDeleteHistory(String id) {
    context.read<AnalysisProvider>().deleteAnalysis(id);
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
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
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
                      color: AppColors.emerald500.withValues(alpha: 0.3),
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
              // AI Status indicator
              _buildAIStatusDot(provider),
              const SizedBox(width: 8),
              if (_view != AppView.home)
                IconButton(
                  tooltip: 'Nuevo análisis',
                  icon: const Icon(Icons.add, color: AppColors.zinc400),
                  onPressed: () {
                    provider.reset();
                    setState(() => _view = AppView.home);
                  },
                ),
              IconButton(
                tooltip: 'Historial',
                icon: Icon(
                  Icons.history,
                  color: _view == AppView.history
                      ? AppColors.emerald500
                      : AppColors.zinc400,
                ),
                onPressed: () => setState(() => _view = AppView.history),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout,
                    color: AppColors.zinc600, size: 20),
                onPressed: _confirmLogout,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAIStatusDot(AnalysisProvider provider) {
    final gemini = provider.aiAvailability['gemini'] ?? false;
    final ollama = provider.aiAvailability['ollama'] ?? false;
    final color = gemini
        ? AppColors.emerald400
        : ollama
            ? AppColors.amber400
            : AppColors.red400;
    final label = gemini ? 'Gemini' : ollama ? 'Ollama' : 'Sin IA';

    return Tooltip(
      message: 'Motor IA: $label',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.zinc900,
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white)),
        content: const Text('¿Desea cerrar la sesión actual?',
            style: TextStyle(color: AppColors.zinc400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red500),
            child: const Text('Cerrar sesión'),
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
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // New Analysis Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.zinc900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.zinc800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.biotech,
                            color: AppColors.emerald500, size: 24),
                        SizedBox(width: 10),
                        Text(
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
                      'Capture o suba una imagen de la munición para iniciar el análisis balístico con IA.',
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

              // Stats + AI Info
              Row(
                children: [
                  Expanded(child: _buildStatsCard(provider)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAIInfoCard(provider)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(AnalysisProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.zinc900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.zinc800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storage, size: 20, color: AppColors.zinc500),
          const SizedBox(height: 8),
          Text(
            '${provider.history.length}',
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
    );
  }

  Widget _buildAIInfoCard(AnalysisProvider provider) {
    final gemini = provider.aiAvailability['gemini'] ?? false;
    final ollama = provider.aiAvailability['ollama'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.zinc900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.zinc800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology, size: 20, color: AppColors.zinc500),
          const SizedBox(height: 8),
          Text(
            gemini ? 'Gemini' : ollama ? 'Ollama' : 'Sin IA',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: gemini || ollama ? AppColors.emerald400 : AppColors.red400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            gemini
                ? 'Visión real activa'
                : ollama
                    ? 'Modelo local'
                    : 'Configurar .env',
            style: const TextStyle(fontSize: 10, color: AppColors.zinc500),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  provider.reset();
                  setState(() => _view = AppView.home);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 18, color: AppColors.zinc500),
                    SizedBox(width: 4),
                    Text('Volver',
                        style:
                            TextStyle(color: AppColors.zinc500, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (provider.isAnalyzing)
                _buildLoadingState()
              else if (provider.error != null)
                _buildErrorState(provider)
              else if (provider.currentAnalysis != null)
                Column(
                  children: [
                    // Provider badge
                    _buildProviderBadge(provider),
                    const SizedBox(height: 16),
                    AnalysisResultWidget(
                      analysis: provider.currentAnalysis!,
                      onSaveNotes: (notes) => provider.saveNotes(
                          provider.currentAnalysis!.id, notes),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderBadge(AnalysisProvider provider) {
    final analysis = provider.currentAnalysis!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.emerald500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.emerald400),
          const SizedBox(width: 8),
          Text(
            'Analizado con ${analysis.aiProvider}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.emerald400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${(analysis.responseTimeMs / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.zinc500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
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
            SizedBox(height: 24),
            Text(
              'Procesando Evidencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Analizando con inteligencia artificial...',
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

  Widget _buildErrorState(AnalysisProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.red500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.red500.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.red400),
          const SizedBox(height: 16),
          Text(
            provider.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red400, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              provider.reset();
              setState(() => _view = AppView.home);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
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
                  history: provider.history,
                  onSelect: _onSelectHistory,
                  onDelete: _onDeleteHistory,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.zinc900)),
      ),
      child: const Text(
        'CALIBERIA V2.0 // IA DUAL // INVESTIGACIÓN ACADÉMICA // 2026',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          color: AppColors.zinc600,
          fontFamily: 'monospace',
          letterSpacing: 2,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_analysis.dart';
import '../theme.dart';

class AnalysisResultWidget extends StatelessWidget {
  final BallisticAnalysis analysis;
  final void Function(String notes) onSaveNotes;

  const AnalysisResultWidget({
    super.key,
    required this.analysis,
    required this.onSaveNotes,
  });

  @override
  Widget build(BuildContext context) {
    final r = analysis.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(
                  base64Decode(analysis.imageBase64),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.zinc900,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: AppColors.zinc600),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    _badge('Identificado', AppColors.emerald500, Colors.white),
                    const SizedBox(width: 8),
                    _badge(
                      'Confianza: ${(r.confidence * 100).toStringAsFixed(1)}%',
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Data cards grid
        _DataCard(icon: Icons.gps_fixed, label: 'Calibre Estimado', value: r.caliber),
        const SizedBox(height: 12),
        _DataCard(icon: Icons.shield, label: 'Tipo de Munición', value: r.ammoType),
        const SizedBox(height: 12),
        _DataCard(icon: Icons.info_outline, label: 'Arma Compatible', value: r.compatibleWeapon),
        const SizedBox(height: 12),
        _DataCard(icon: Icons.straighten, label: 'Longitud Estimada', value: r.estimatedLength),
        const SizedBox(height: 20),

        // Brands
        _buildSection(
          icon: Icons.label_outline,
          title: 'POSIBLES FABRICANTES',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.possibleBrands
                .map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.zinc800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.zinc700),
                      ),
                      child: Text(b, style: const TextStyle(color: AppColors.zinc300, fontSize: 13)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        _buildSection(
          icon: Icons.description_outlined,
          title: 'NOTAS DE INVESTIGACIÓN',
          child: TextField(
            controller: TextEditingController(text: analysis.notes),
            onChanged: onSaveNotes,
            maxLines: 4,
            style: const TextStyle(color: AppColors.zinc300, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Agregar observaciones forenses...',
              hintStyle: const TextStyle(color: AppColors.zinc600),
              filled: true,
              fillColor: AppColors.zinc950,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.zinc800),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.zinc800),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Metadata
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 12, color: AppColors.zinc500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(analysis.timestamp),
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.zinc500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Text(
                'ID: ${analysis.id}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.zinc500,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.zinc900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.zinc800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.zinc400),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.zinc400,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.zinc900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.zinc800),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.zinc950,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc800),
            ),
            child: Icon(icon, size: 20, color: AppColors.emerald500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.zinc500,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.zinc100,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

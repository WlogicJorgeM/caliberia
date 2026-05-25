import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ballistic_analysis.dart';
import '../theme.dart';

class HistoryListWidget extends StatelessWidget {
  final List<BallisticAnalysis> history;
  final void Function(BallisticAnalysis) onSelect;
  final void Function(String id) onDelete;

  const HistoryListWidget({
    super.key,
    required this.history,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 48, color: AppColors.zinc500.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No hay registros previos',
              style: TextStyle(color: AppColors.zinc500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = history[index];
        return _HistoryTile(
          item: item,
          onTap: () => onSelect(item),
          onDelete: () => onDelete(item.id),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final BallisticAnalysis item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.zinc900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.zinc800),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.memory(
                  base64Decode(item.imageBase64),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.zinc800,
                    child: const Icon(Icons.image, color: AppColors.zinc600, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.results.caliber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald500,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(item.timestamp),
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.zinc500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.results.ammoType,
                    style: const TextStyle(fontSize: 12, color: AppColors.zinc400),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.results.compatibleWeapon,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.zinc600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Actions
            Column(
              children: [
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: AppColors.zinc600),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.zinc700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

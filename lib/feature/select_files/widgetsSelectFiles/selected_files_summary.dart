import 'package:flutter/material.dart';
import 'package:share_up_front/feature/select_files/select_files_state.dart';

class SelectedFilesSummary extends StatelessWidget {
  final List<FileItemModel> files;
  final ValueChanged<FileItemModel> onRemove;

  const SelectedFilesSummary({
    super.key,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final totalSizeMb = files.fold<double>(
      0,
      (total, file) => total + _parseSizeInMb(file.size),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFFA21CAF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${files.length} fichier(s) sélectionné(s)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${totalSizeMb.toStringAsFixed(1)} MB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: files.map((file) {
              return _SelectedFileChip(
                label: _truncateFileName(file.name),
                onRemove: () => onRemove(file),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SelectedFileChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedFileChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

double _parseSizeInMb(String sizeLabel) {
  final parts = sizeLabel.trim().split(' ');
  if (parts.length != 2) return 0;

  final value = double.tryParse(parts.first.replaceAll(',', '.')) ?? 0;
  final unit = parts.last.toUpperCase();

  switch (unit) {
    case 'GB':
      return value * 1024;
    case 'KB':
      return value / 1024;
    case 'B':
      return value / (1024 * 1024);
    case 'MB':
    default:
      return value;
  }
}

String _truncateFileName(String name) {
  const maxLength = 16;
  if (name.length <= maxLength) return name;
  return '${name.substring(0, maxLength - 3)}...';
}

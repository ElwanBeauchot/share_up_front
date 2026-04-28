import 'package:flutter/material.dart';
import 'package:share_up_front/feature/history/history_state.dart';
import 'package:share_up_front/theme/app_colors.dart';


class HistoryFilterBar extends StatelessWidget {
  final HistoryFilter selectedFilter; // L'etat actuel du filtre selectionné
  final ValueChanged<HistoryFilter> onChanged;

  const HistoryFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Tous',
            isSelected: selectedFilter == HistoryFilter.all,
            onTap: () => onChanged(HistoryFilter.all),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Reçus',
            isSelected: selectedFilter == HistoryFilter.received,
            onTap: () => onChanged(HistoryFilter.received),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Envoyés',
            isSelected: selectedFilter == HistoryFilter.sent,
            onTap: () => onChanged(HistoryFilter.sent),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap; // Callback pour gérer le tap sur le chip il attend rien et retourne rien

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell( // Permet de rendre clickable 
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.indigo : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}

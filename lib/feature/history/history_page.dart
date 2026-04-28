import 'package:flutter/material.dart';
import 'package:share_up_front/feature/history/history_controller.dart';
import 'package:share_up_front/feature/history/history_state.dart';
import 'package:share_up_front/feature/history/widgetsHistory/history_filter_bar.dart';
import 'package:share_up_front/feature/history/widgetsHistory/history_header.dart';
import 'package:share_up_front/feature/history/widgetsHistory/transfer_history_card.dart';
import 'package:share_up_front/theme/app_theme.dart';
import 'package:share_up_front/widgets/slide_fade_in.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryController _controller;
// Creation de la page  
  @override
  void initState() {
    super.initState();
    _controller = HistoryController();
    _controller.loadHistoryData();
  }
// Destruction de la page
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FA),
      body: SafeArea(
        child: ValueListenableBuilder<HistoryState>( // ValueListenableBuilder pour écouter les changements d'état du controller
          valueListenable: _controller,
          builder: (context, state, _) {
            final filteredTransfers = state.filteredTransfers;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HistoryHeader(),
                  const SizedBox(height: 14),
                  Text(
                    state.isLoading
                        ? 'Chargement de l’historique...'
                        : '${filteredTransfers.length} transfer(s) récent(s)',
                    style: const TextStyle(
                      fontSize: AppTextSizes.headerTitleM,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 18),
                  HistoryFilterBar(
                    selectedFilter: state.selectedFilter,
                    onChanged: _controller.setFilter,
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: state.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                          // Affichage de la liste des transferts filtrés avec des animations d'entrée
                        : ListView.separated(
                            key: ValueKey(
                              'history_list_${state.selectedFilter.name}_${state.animationSeed}', 
                            ),
                            itemCount: filteredTransfers.length,
                            separatorBuilder: (_, __) => 
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final transfer = filteredTransfers[index];
                              return SlideFadeIn(
                                key: ValueKey(
                                  'history_${transfer.deviceName}_${transfer.timeLabel}_${state.selectedFilter.name}_${state.animationSeed}',
                                ),
                                delay: Duration(milliseconds: 70 * index),
                                child: TransferHistoryCard(item: transfer),
                              );
                            },
                          ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

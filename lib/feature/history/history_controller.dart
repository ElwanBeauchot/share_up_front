import 'package:flutter/foundation.dart';
import 'package:share_up_front/feature/history/history_state.dart';
import 'package:share_up_front/feature/history/widgetsHistory/transfer_history_card.dart';

class HistoryController extends ValueNotifier<HistoryState> {
  HistoryController() : super(const HistoryState());

  Future<void> loadHistoryData() async {
    // TODO: remplacer ce faux chargement par le vrai appel API/service
    // qui recupere l'historique des transferts.
    // Exemple plus tard:
    // 1. await historyService.getTransfers()
    // 2. mapper la reponse dans TransferHistoryItem
    // 3. mettre a jour transfers avec les vraies donnees
    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      await Future.delayed(const Duration(milliseconds: 1100));

      value = value.copyWith(
        isLoading: false,
        transfers: const [
          TransferHistoryItem(
            deviceName: 'iPhone de Marie',
            detail: '3 fichiers',
            timeLabel: 'Il y a 5 min',
            sizeLabel: '8.5 MB',
            direction: TransferDirection.received,
          ),
          TransferHistoryItem(
            deviceName: 'Samsung Galaxy S23',
            detail: 'Document.pdf',
            timeLabel: 'Il y a 1 heure',
            sizeLabel: '1.2 MB',
            direction: TransferDirection.sent,
          ),
          TransferHistoryItem(
            deviceName: 'MacBook Pro',
            detail: '5 fichiers',
            timeLabel: 'Il y a 3 heures',
            sizeLabel: '15.3 MB',
            direction: TransferDirection.received,
          ),
          TransferHistoryItem(
            deviceName: 'iPad Air',
            detail: '2 fichiers',
            timeLabel: 'Hier',
            sizeLabel: '24.8 MB',
            direction: TransferDirection.sent,
          ),
          TransferHistoryItem(
            deviceName: 'Pixel 8',
            detail: '12 fichiers',
            timeLabel: 'Hier',
            sizeLabel: '42.1 MB',
            direction: TransferDirection.received,
          ),
        ],
        animationSeed: value.animationSeed + 1,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger l historique des transferts.',
      );
    }
  }

  void setFilter(HistoryFilter filter) {
    value = value.copyWith(
      selectedFilter: filter,
      animationSeed: value.animationSeed + 1,
    );
  }
}

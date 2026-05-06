import 'package:flutter/foundation.dart';
import 'package:share_up_front/feature/history/history_service.dart';
import 'package:share_up_front/feature/history/history_state.dart';

class HistoryController extends ValueNotifier<HistoryState> {
  HistoryController() : super(const HistoryState());

  Future<void> loadHistoryData() async {
    value = value.copyWith(isLoading: true, errorMessage: null);

    try {
      final transfers = await loadRecords();

      value = value.copyWith(
        isLoading: false,
        transfers: transfers,
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

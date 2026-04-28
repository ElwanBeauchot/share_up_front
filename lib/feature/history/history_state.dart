import 'package:share_up_front/feature/history/widgetsHistory/transfer_history_card.dart';

enum HistoryFilter {
  all,
  received,
  sent,
}

class HistoryState {
  final bool isLoading;
  final HistoryFilter selectedFilter;
  final List<TransferHistoryItem> transfers;
  final String? errorMessage;
  final int animationSeed;

  const HistoryState({
    this.isLoading = true,
    this.selectedFilter = HistoryFilter.all,
    this.transfers = const [],
    this.errorMessage,
    this.animationSeed = 0,
  });

  List<TransferHistoryItem> get filteredTransfers {
    return transfers.where((transfer) {
      switch (selectedFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.received:
          return transfer.direction == TransferDirection.received;
        case HistoryFilter.sent:
          return transfer.direction == TransferDirection.sent;
      }
    }).toList();
  }

  HistoryState copyWith({
    bool? isLoading,
    HistoryFilter? selectedFilter,
    List<TransferHistoryItem>? transfers,
    String? errorMessage,
    int? animationSeed,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      transfers: transfers ?? this.transfers,
      errorMessage: errorMessage,
      animationSeed: animationSeed ?? this.animationSeed,
    );
  }
}

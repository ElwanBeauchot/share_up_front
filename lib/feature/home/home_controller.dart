import 'package:flutter/foundation.dart';
import 'package:share_up_front/feature/history/history_service.dart';
import 'home_state.dart';

class HomeController extends ValueNotifier<HomeState> {
  HomeController() : super(const HomeState());

  Future<void> loadHomeData() async {
    value = value.copyWith(isLoading: true, errorMessage: null);

    try {
      final stats = await loadHistoryStats();

      value = value.copyWith(
        isLoading: false,
        receivedCount: stats.receivedCount,
        sentCount: stats.sentCount,
        errorMessage: null,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les donnees de la page d accueil.',
      );
    }
  }
}

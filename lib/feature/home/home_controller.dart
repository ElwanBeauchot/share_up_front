import 'package:flutter/foundation.dart';
import 'home_state.dart';

class HomeController extends ValueNotifier<HomeState> {
  HomeController() : super(const HomeState());

  Future<void> loadHomeData() async {
    value = value.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      // TODO: remplacer ce faux chargement par le vrai appel API/service
      // pour recuperer le resume de la home.
      // Exemple plus tard:
      // 1. await homeService.getSummary()
      // 2. mapper la reponse back en receivedCount / sentCount
      // 3. mettre a jour le state avec les vraies donnees
      await Future.delayed(const Duration(milliseconds: 900));

      value = value.copyWith(
        isLoading: false,
        receivedCount: 12,
        sentCount: 8,
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

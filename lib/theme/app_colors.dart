import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color indigo = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF9333EA);
  static const Color pink = Color(0xFFB832F2);

  // Backgrounds
  static const Color scanBg = Color(0xFFF4F6FF);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, purple, pink],
  );

  // Petit gradient utile pour l’icône rond téléphone
  static const LinearGradient iconGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, purple, pink],
  );
}

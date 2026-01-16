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

  // File type colors
  static const Color fileImage = Color(0xFF2563EB);
  static const Color filePdf = Color(0xFFF97316);
  static const Color fileAudio = Color(0xFF22C55E);
  static const Color fileVideo = Color(0xFF8B5CF6);
  static const Color filePpt = Color(0xFFF97316);
  static const Color fileOther = Color(0xFF64748B);

}



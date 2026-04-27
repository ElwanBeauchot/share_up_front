import 'package:flutter/material.dart';
import 'package:share_up_front/theme/app_theme.dart';

class SelectFilesHeader extends StatelessWidget {
  final String deviceName;

  const SelectFilesHeader({
    super.key,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: Color(0xFF4B5563),
                ),
                SizedBox(width: 8),
                Text(
                  'Retour',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 26),

        const Text(
          'Sélectionner des fichiers',
          style: TextStyle(
            fontSize: AppTextSizes.headerTitleL,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            height: 1.1,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Envoi vers $deviceName',
          style: const TextStyle(
            fontSize: AppTextSizes.headerTitleM,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }
}

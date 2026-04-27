import 'package:flutter/material.dart';
import 'package:share_up_front/theme/app_theme.dart';

class MainCard extends StatelessWidget {
  final VoidCallback onPressed;

  const MainCard({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: (375),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'Prêt à partager ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Détectez les appareils à proximité et\ntransférez vos fichiers',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              child: Text("Démarrer le scan"),
            ),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:share_up_front/theme/app_theme.dart';

class HistoryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const HistoryButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.12),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history),
          SizedBox(width: 15),
          Text("Historique des transferts"),
        ],
      ),
    );
  }
}

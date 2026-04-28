import 'package:flutter/material.dart';

class SendButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback? onPressed;

  const SendButton({
    super.key,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? const Color(0xFF4F39F6)
              : const Color(0xFFE1E3E8),
          foregroundColor: isEnabled
              ? Colors.white
              : const Color(0xFFA5AFC0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: const Text(
          'Envoyer',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

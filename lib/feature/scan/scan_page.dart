import 'package:flutter/material.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: const Center(child: Text('Ici on fera le scan + loading + liste.')),
    );
  }
}

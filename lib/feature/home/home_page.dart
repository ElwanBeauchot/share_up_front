import 'package:flutter/material.dart';
import 'widgets/header.dart';
import 'widgets/main_card.dart';
import 'widgets/stats_card.dart';
import 'widgets/history_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5A46F3),
              Color(0xFFB12EF0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: const [
                SizedBox(height: 20),
                Header(),
                SizedBox(height: 40),
                MainCard(),
                SizedBox(height: 20),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        icon: Icons.download,
                        title: 'Reçus',
                        count: '0',
                        subtitle: 'fichiers',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        icon: Icons.upload,
                        title: 'Envoyés',
                        count: '0',
                        subtitle: 'fichiers',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),
                HistoryButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:share_up_front/feature/history/history_page.dart';
import 'package:share_up_front/feature/scan/scan_page.dart';
import 'home_controller.dart';
import 'home_state.dart';
import 'widgetsHome/header.dart';
import 'widgetsHome/history_button.dart';
import 'widgetsHome/main_card.dart';
import 'widgetsHome/stats_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;

// Creation de la page  
  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.loadHomeData();
  }

// Destruction de la page
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          child: ValueListenableBuilder<HomeState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Header(),
                    const SizedBox(height: 40),
                    MainCard(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScanPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            icon: Icons.download,
                            title: 'Reçus',
                            count: state.isLoading
                                ? '...'
                                : '${state.receivedCount}',
                            subtitle: 'fichiers',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatsCard(
                            icon: Icons.upload,
                            title: 'Envoyés',
                            count: state.isLoading
                                ? '...'
                                : '${state.sentCount}',
                            subtitle: 'fichiers',
                          ),
                        ),
                      ],
                    ),

                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 16),
                    HistoryButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoryPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

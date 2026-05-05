import 'package:flutter/material.dart';
import 'feature/home/home_page.dart';
import 'widgets/transfer_banner.dart';

// Clé globale conservée pour d'éventuels futurs dialogs déclenchés depuis un
// service. La bannière de transfert n'en a plus besoin (elle vit dans le
// builder du MaterialApp).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ShareUpApp extends StatelessWidget {
  const ShareUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareUp',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const TransferBanner(),
          ],
        );
      },
    );
  }
}

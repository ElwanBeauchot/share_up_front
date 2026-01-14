import 'package:flutter/material.dart';
import 'feature/home/home_page.dart';

class ShareUpApp extends StatelessWidget {
  const ShareUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

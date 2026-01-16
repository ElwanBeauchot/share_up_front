import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'feature/home/home_page.dart';
import 'services/p2p_service.dart';

class ShareUpApp extends StatefulWidget {
  const ShareUpApp({super.key});

  @override
  State<ShareUpApp> createState() => _ShareUpAppState();
}

class _ShareUpAppState extends State<ShareUpApp> {
  final P2PService _p2pService = P2PService.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _p2pService.onMessageReceived = _handleReceivedMessage;
    Future.delayed(const Duration(seconds: 2), () {
      _p2pService.startListening();
    });
  }

  Future<void> _handleReceivedMessage(String message) async {
    if (!message.startsWith('data:')) {
      _showDialog('Message: $message');
      return;
    }

    try {
      final parts = message.split(',');
      final mimeType = parts[0].split(';')[0].split(':')[1];
      final fileBytes = base64Decode(parts[1]);
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/fichier_${DateTime.now().millisecondsSinceEpoch}${_getExtensionFromMimeType(mimeType)}',
      );
      await file.writeAsBytes(fileBytes);
      _showDialog('Fichier sauvegardé');
    } catch (e) {
      _showDialog('Erreur sauvegarde fichier');
    } finally {
      await _p2pService.disconnect();
    }
  }

  void _showDialog(String text) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getExtensionFromMimeType(String mimeType) {
    final map = {
      'application/pdf': '.pdf',
      'application/zip': '.zip',
      'text/plain': '.txt',
      'text/csv': '.csv',
      'application/json': '.json',
      'video/mp4': '.mp4',
      'audio/mpeg': '.mp3',
    };
    return map[mimeType] ?? '.bin';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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

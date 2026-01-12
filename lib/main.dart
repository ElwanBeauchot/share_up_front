import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Share Up Front',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ApiService _api = ApiService();
  bool _loading = false;
  String _message = '';
  Map<String, dynamic>? _response;

  Future<void> _test() async {
    setState(() {
      _loading = true;
      _message = '';
      _response = null;
    });

    try {
      final data = await _api.get('/');
      setState(() {
        _message = 'Connecté!';
        _response = data;
      });
    } catch (e) {
      setState(() {
        _message = 'Erreur: $e';
        print(e);
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Up'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('URL: ${ApiConfig.baseUrl}'),
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else if (_message.isNotEmpty)
              Text(_message),
            if (_response != null) ...[
              const SizedBox(height: 16),
              Text(_response.toString()),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _test,
              child: const Text('Tester'),
            ),
          ],
        ),
      ),
    );
  }
}

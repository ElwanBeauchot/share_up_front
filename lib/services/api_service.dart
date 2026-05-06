import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  //String apiUrl = dotenv.env['API_URL']!;
  String apiUrl = "http://10.57.33.146:8080";
  String apiKey = dotenv.env['API_KEY']!;

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$apiUrl$endpoint');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
            body: jsonEncode(data),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'code': 200,
          'message': 'Success',
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      } else {
        print('Erreur API POST: ${response.statusCode} - ${response.body}');
        return {'code': response.statusCode, 'message': response.body};
      }
    } on TimeoutException catch (e) {
      print('Timeout API POST $endpoint: $e');
      return {'code': 408, 'message': 'Request timed out'};
    } catch (e) {
      print('Erreur API POST $endpoint: $e');
      return {'code': 500, 'message': 'Internal error'};
    }
  }

  /// Ouvre une connexion SSE (Server-Sent Events) sur [endpoint] et émet
  /// chaque event JSON reçu. La stream se termine si le serveur ferme,
  /// si une erreur survient, ou si l'écouteur cancel sa subscription.
  Stream<Map<String, dynamic>> streamEvents(String endpoint) async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$apiUrl$endpoint'));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['x-api-key'] = apiKey;

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('SSE refusé: HTTP ${response.statusCode}');
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final dataBuffer = StringBuffer();
      await for (final line in lines) {
        if (line.isEmpty) {
          // Ligne vide = fin d'event SSE.
          final raw = dataBuffer.toString();
          dataBuffer.clear();
          if (raw.isEmpty) continue;
          yield jsonDecode(raw) as Map<String, dynamic>;
        } else if (line.startsWith('data:')) {
          dataBuffer.write(line.substring(5).trimLeft());
        }
        // On ignore les autres lignes (event:, id:, retry:, commentaires).
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$apiUrl$endpoint');
    try {
      final response = await http
          .get(url, headers: {'x-api-key': apiKey})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'code': 200,
          'message': 'Success',
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      } else {
        print('Erreur API POST: ${response.statusCode} - ${response.body}');
        return {'code': response.statusCode, 'message': response.body};
      }
    } on TimeoutException catch (e) {
      print('Timeout API POST $endpoint: $e');
      return {'code': 408, 'message': 'Request timed out'};
    } catch (e) {
      print('Erreur API POST $endpoint: $e');
      return {'code': 500, 'message': 'Internal error'};
    }
  }
}

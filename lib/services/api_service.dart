import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  //String apiUrl = dotenv.env['API_URL']!;
  String apiUrl = "http://10.105.58.165:8080";
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
        return {'code': 200, 'message': 'Success', 'data': jsonDecode(response.body) as Map<String, dynamic>};
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

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$apiUrl$endpoint');
    try {
      final response = await http
          .get(url, headers: {'x-api-key': apiKey})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return {'code': 200, 'message': 'Success', 'data': jsonDecode(response.body) as Map<String, dynamic>};
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

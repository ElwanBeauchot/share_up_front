import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(data))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {};
      }
    } on TimeoutException catch (e) {
      print('[API] Timeout: $endpoint');
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {};
      }
    } on TimeoutException catch (e) {
      print('[API] Timeout: $endpoint');
      return {};
    } catch (e) {
      return {};
    }
  }
}

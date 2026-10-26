import 'dart:convert';

import 'package:http/http.dart' as http;

import 'transport_stub.dart' if (dart.library.js_interop) 'transport_web.dart';

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final http.Client client;
  String? token;
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8000/api/v1',
          ),
      client = client ?? createClient();
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (data != null) req.body = jsonEncode(data);
    try {
      final response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 15)),
      );
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
      if (response.statusCode >= 400) {
        final detail = body is Map ? body['detail'] : null;
        throw ApiError(
          detail is String ? detail : 'Check the form fields and try again.',
          response.statusCode,
        );
      }
      return body;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(
        'Cannot reach the studio server. Check your connection and try again.',
      );
    }
  }

  void close() => client.close();
}

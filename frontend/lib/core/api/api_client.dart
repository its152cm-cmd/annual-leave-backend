import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when the backend returns an error or cannot be reached.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(${statusCode ?? 'no status'}): $message';
}

/// Sends HTTP requests to the Python (FastAPI) backend and returns the
/// decoded JSON (a Map, a List, or null for an empty response).
class ApiClient {
  final String baseUrl;

  /// The signed-in session, shared by every ApiClient in the app.
  static String? sessionToken;
  static String? refreshToken;

  /// Set by AccountService: asks the backend for a new token. True if it worked.
  static Future<bool> Function()? onTokenExpired;

  /// Optional token for one client; otherwise the signed-in session is used.
  String? authToken;

  /// Backend address. Set it when building for launch:
  ///   flutter build web --dart-define=API_URL=https://your-backend-url
  /// Without it the app talks to the backend on your own computer.
  static const String defaultBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

  ApiClient({this.baseUrl = defaultBaseUrl, this.authToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if ((authToken ?? sessionToken) != null)
          'Authorization': 'Bearer ${authToken ?? sessionToken}',
      };

  Uri _uri(String path, Map<String, dynamic>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => http.get(_uri(path, query), headers: _headers));
  }

  Future<dynamic> post(String path, [Object? body]) {
    return _send(() => http.post(
          _uri(path, null),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> put(String path, [Object? body]) {
    return _send(() => http.put(
          _uri(path, null),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, [Object? body]) {
    return _send(() => http.patch(
          _uri(path, null),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path) {
    return _send(() => http.delete(_uri(path, null), headers: _headers));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
      // The login token lasts about an hour: renew it once and try again.
      if (response.statusCode == 401 &&
          sessionToken != null &&
          onTokenExpired != null &&
          await onTokenExpired!()) {
        response = await request();
      }
    } catch (e) {
      throw ApiException('Cannot reach the server at $baseUrl ($e)');
    }

    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : _tryDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // FastAPI sends errors as {"detail": "..."}
    String message = 'Request failed';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    } else if (text.isNotEmpty) {
      message = text;
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }
}

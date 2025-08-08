import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Change to your deployed backend URL as needed
  String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.2:8080/api/v1',
  );

  String? _authToken;

  String? get authToken => _authToken;
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      },
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    _ensureOk(res);
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> postJson(String path, Object? body) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _ensureOk(res, createdOk: true);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putJson(String path, Object? body) async {
    final res = await http.put(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers());
    if (!(res.statusCode >= 200 && res.statusCode < 300)) {
      throw ApiError('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  void _ensureOk(http.Response res, {bool createdOk = false}) {
    final ok = createdOk
        ? (res.statusCode == 200 || res.statusCode == 201)
        : (res.statusCode >= 200 && res.statusCode < 300);
    if (!ok) {
      throw ApiError('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => 'ApiError: $message';
}

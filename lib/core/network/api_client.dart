import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  /// Se invoca ante respuestas 401 (sesión inválida / usuario inexistente).
  void Function()? onUnauthorized;

  /// Evita disparar [onUnauthorized] durante restore/refresh de sesión.
  bool suppressUnauthorized = false;

  /// Renueva el access token con la sesión persistida.
  Future<bool> Function()? onAccessTokenExpired;
  Future<bool>? _refreshInProgress;

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParameters,
    );
    final response = await _sendWithRefresh(
      () => _client.get(uri, headers: _headers(authenticated: authenticated)),
      authenticated: authenticated,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final response = await _sendWithRefresh(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(authenticated: authenticated),
        body: body == null ? null : jsonEncode(body),
      ),
      authenticated: authenticated,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final response = await _sendWithRefresh(
      () => _client.put(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(authenticated: authenticated),
        body: body == null ? null : jsonEncode(body),
      ),
      authenticated: authenticated,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final response = await _sendWithRefresh(
      () => _client.patch(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(authenticated: authenticated),
        body: body == null ? null : jsonEncode(body),
      ),
      authenticated: authenticated,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = false,
  }) async {
    final response = await _sendWithRefresh(
      () => _client.delete(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, MultipartFileData>? files,
    bool authenticated = false,
  }) async {
    return _sendMultipart('POST', path,
        fields: fields, files: files, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> putMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, MultipartFileData>? files,
    bool authenticated = false,
  }) async {
    return _sendMultipart('PUT', path,
        fields: fields, files: files, authenticated: authenticated);
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParameters,
    );
    final response = await _sendWithRefresh(
      () => _client.get(uri, headers: _headers(authenticated: authenticated)),
      authenticated: authenticated,
    );
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> _sendMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    Map<String, MultipartFileData>? files,
    required bool authenticated,
  }) async {
    final response = await _sendWithRefresh(() async {
      final request = http.MultipartRequest(
        method,
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );

      if (authenticated && _accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      for (final entry
          in files?.entries ?? const <MapEntry<String, MultipartFileData>>[]) {
        request.files.add(
          http.MultipartFile.fromBytes(
            entry.key,
            entry.value.bytes,
            filename: entry.value.filename,
            contentType: MediaType.parse(entry.value.mimeType),
          ),
        );
      }

      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }, authenticated: authenticated);
    return _handleMapResponse(response);
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() send, {
    required bool authenticated,
  }) async {
    var response = await send();
    if (!authenticated ||
        response.statusCode != 401 ||
        onAccessTokenExpired == null) {
      return response;
    }

    final refreshed = await (_refreshInProgress ??= _refreshAccessToken());
    if (refreshed) response = await send();
    return response;
  }

  Future<bool> _refreshAccessToken() async {
    try {
      return await onAccessTokenExpired?.call() ?? false;
    } finally {
      _refreshInProgress = null;
    }
  }

  Map<String, String> _headers({required bool authenticated}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _handleMapResponse(http.Response response) {
    final decoded = _decodeBody(response);
    final body =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    _notifyUnauthorizedIfNeeded(response.statusCode);

    final message =
        _extractMessage(body) ?? 'Error del servidor (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }

  List<Map<String, dynamic>> _handleListResponse(http.Response response) {
    final decoded = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        return (decoded['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    }

    _notifyUnauthorizedIfNeeded(response.statusCode);

    final body =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final message =
        _extractMessage(body) ?? 'Error del servidor (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }

  void _notifyUnauthorizedIfNeeded(int statusCode) {
    if (statusCode == 401 && !suppressUnauthorized) {
      onUnauthorized?.call();
    }
  }

  String? _extractMessage(Map<String, dynamic> body) {
    final message = body['message'];
    if (message is String) return message;
    if (message is List) return message.join(', ');
    return body['error'] as String?;
  }
}

class MultipartFileData {
  const MultipartFileData({
    required this.bytes,
    required this.filename,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

import 'dart:convert';

import '../../../core/models/api_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user_role.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _api = apiClient ?? ApiClient(),
        _storage = tokenStorage ?? TokenStorage() {
    _api.onAccessTokenExpired = _refreshStoredSession;
  }

  final ApiClient _api;
  final TokenStorage _storage;

  ApiClient get apiClient => _api;

  /// Login único. [expectedRole] solo se valida si se pasa (p. ej. admin).
  Future<AuthResponse> login({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final json = await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final response = AuthResponse.fromJson(json);

    if (expectedRole != null && response.user.userRole != expectedRole) {
      throw ApiException(
        'Esta cuenta no corresponde al perfil ${expectedRole.title}.',
      );
    }

    await _persistSession(response);
    return response;
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final json = await _api.post(
      '/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': UserRole.cliente.apiValue,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      },
    );
    final response = AuthResponse.fromJson(json);
    await _persistSession(response);
    return response;
  }

  Future<AuthResponse> promoteToComerciante() async {
    final json = await _api.post(
      '/auth/promote-comerciante',
      authenticated: true,
    );
    final response = AuthResponse.fromJson(json);
    await _persistSession(response);
    return response;
  }

  Future<AuthResponse?> restoreSession() async {
    final stored = await _storage.readSession();
    if (stored == null) return null;

    _api.setAccessToken(stored.accessToken);
    _api.suppressUnauthorized = true;

    try {
      return await _validateWithMe(stored.refreshToken);
    } on ApiException {
      return _restoreCachedSession(stored);
    } catch (_) {
      return _restoreCachedSession(stored);
    } finally {
      _api.suppressUnauthorized = false;
    }
  }

  Future<AuthResponse> _validateWithMe(String refreshToken) async {
    final me = await _api.get('/users/me', authenticated: true);
    final activo = me['activo'];
    if (activo == false) {
      throw ApiException('Cuenta suspendida', statusCode: 401);
    }

    final user = UserModel.fromJson(me);
    final stored = await _storage.readSession();
    final response = AuthResponse(
      accessToken: _api.accessToken ?? '',
      refreshToken: stored?.refreshToken ?? refreshToken,
      user: user,
    );
    await _persistSession(response);
    return response;
  }

  Future<AuthResponse> _refreshSession(String refreshToken) async {
    final json = await _api.post(
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    final response = AuthResponse.fromJson(json);
    await _persistSession(response);
    return response;
  }

  Future<bool> _refreshStoredSession() async {
    final stored = await _storage.readSession();
    if (stored == null) return false;
    try {
      await _refreshSession(stored.refreshToken);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return false;
      }
      rethrow;
    }
  }

  AuthResponse _restoreCachedSession(StoredSession stored) {
    final user = UserModel.fromJson(
      jsonDecode(stored.userJson) as Map<String, dynamic>,
    );
    return AuthResponse(
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
      user: user,
    );
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', authenticated: true);
    } catch (_) {
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _api.setAccessToken(null);
    await _storage.clear();
  }

  Future<void> _persistSession(AuthResponse response) async {
    _api.setAccessToken(response.accessToken);
    await _storage.saveSession(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      userJson: jsonEncode(response.user.toJson()),
    );
  }
}

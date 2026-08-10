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
        _storage = tokenStorage ?? TokenStorage();

  final ApiClient _api;
  final TokenStorage _storage;

  ApiClient get apiClient => _api;

  Future<AuthResponse> login({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final json = await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final response = AuthResponse.fromJson(json);

    if (response.user.userRole != expectedRole) {
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
    required UserRole role,
    String? phone,
  }) async {
    final json = await _api.post(
      '/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role.apiValue,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      },
    );
    final response = AuthResponse.fromJson(json);
    await _persistSession(response);
    return response;
  }

  /// Restaura la sesión solo si el usuario sigue existiendo y el token es válido
  /// en la API. Si no, limpia el almacenamiento local y retorna `null`.
  Future<AuthResponse?> restoreSession() async {
    final stored = await _storage.readSession();
    if (stored == null) return null;

    _api.setAccessToken(stored.accessToken);
    _api.suppressUnauthorized = true;

    try {
      return await _validateWithMe(stored.refreshToken);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        try {
          return await _refreshSession(stored.refreshToken);
        } catch (_) {
          await clearLocalSession();
          return null;
        }
      }
      // API no alcanzable o error de servidor: no mantener sesión local stale.
      await clearLocalSession();
      return null;
    } catch (_) {
      await clearLocalSession();
      return null;
    } finally {
      _api.suppressUnauthorized = false;
    }
  }

  Future<AuthResponse> _validateWithMe(String refreshToken) async {
    final me = await _api.get('/users/me', authenticated: true);
    final activo = me['activo'];
    if (activo == false) {
      await clearLocalSession();
      throw ApiException('Cuenta suspendida', statusCode: 401);
    }

    final user = UserModel.fromJson(me);
    final response = AuthResponse(
      accessToken: _api.accessToken ?? '',
      refreshToken: refreshToken,
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

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', authenticated: true);
    } catch (_) {
      // Ignorar errores de red al cerrar sesión localmente.
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

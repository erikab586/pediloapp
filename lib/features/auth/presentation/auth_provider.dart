import 'package:flutter/foundation.dart';

import '../../../core/models/api_models.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _repository.apiClient.onUnauthorized = _handleUnauthorized;
  }

  final AuthRepository _repository;

  UserModel? _user;
  bool _isLoading = false;
  bool _initialized = false;
  bool _handlingUnauthorized = false;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  AuthRepository get repository => _repository;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final session = await _repository.restoreSession();
      _user = session?.user;
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _repository.login(
        email: email,
        password: password,
        expectedRole: expectedRole,
      );
      _user = response.user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _repository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );
      _user = response.user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    notifyListeners();
  }

  /// Cierra sesión local sin llamar al backend (token inválido / usuario borrado).
  Future<void> forceLogout() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      await _repository.clearLocalSession();
      if (_user != null) {
        _user = null;
        notifyListeners();
      }
    } finally {
      _handlingUnauthorized = false;
    }
  }

  void _handleUnauthorized() {
    // Solo cierra si había sesión activa (evita ruido en login fallido).
    if (_user == null || _handlingUnauthorized) return;
    Future.microtask(forceLogout);
  }

  String homeRouteFor(UserRole role) => switch (role) {
        UserRole.cliente => '/cliente/home',
        UserRole.comerciante => '/comerciante/home',
        UserRole.administrador => '/admin/home',
      };

  String? get homeRoute =>
      _user == null ? null : homeRouteFor(_user!.userRole);
}

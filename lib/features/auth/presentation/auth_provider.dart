import 'package:flutter/foundation.dart';

import '../../../core/models/api_models.dart';
import '../../../core/storage/app_mode_storage.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? repository,
    AppModeStorage? modeStorage,
  })  : _repository = repository ?? AuthRepository(),
        _modeStorage = modeStorage ?? AppModeStorage();

  final AuthRepository _repository;
  final AppModeStorage _modeStorage;

  UserModel? _user;
  bool _isLoading = false;
  bool _initialized = false;
  bool _loginNavigationPending = false;
  AppMode _appMode = AppMode.comprador;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  bool get loginNavigationPending => _loginNavigationPending;
  AuthRepository get repository => _repository;
  AppMode get appMode => _appMode;

  bool get canUseComercioMode =>
      _user?.userRole == UserRole.comerciante ||
      _user?.userRole == UserRole.administrador;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _appMode = await _modeStorage.read();
      final session = await _repository.restoreSession();
      _user = session?.user;
      if (_user?.userRole == UserRole.cliente) {
        _appMode = AppMode.comprador;
      }
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    UserRole? expectedRole,
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
      _appMode = AppMode.comprador;
      await _modeStorage.save(_appMode);
      _loginNavigationPending = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _repository.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _user = response.user;
      _appMode = AppMode.comprador;
      await _modeStorage.save(_appMode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> promoteToComerciante() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _repository.promoteToComerciante();
      _user = response.user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateLocalUserContact({
    required String name,
    required String phone,
  }) {
    final currentUser = _user;
    if (currentUser == null) return;
    _user = UserModel(
      id: currentUser.id,
      name: name,
      email: currentUser.email,
      role: currentUser.role,
      phone: phone,
    );
    notifyListeners();
  }

  Future<void> setAppMode(AppMode mode) async {
    if (mode == AppMode.comercio && !canUseComercioMode) return;
    _appMode = mode;
    await _modeStorage.save(mode);
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _loginNavigationPending = false;
    _appMode = AppMode.comprador;
    notifyListeners();
  }

  void completeLoginNavigation() {
    _loginNavigationPending = false;
  }

  String homeRouteFor(UserRole role) {
    return '/cliente/home';
  }

  String? get homeRoute => _user == null ? null : homeRouteFor(_user!.userRole);
}

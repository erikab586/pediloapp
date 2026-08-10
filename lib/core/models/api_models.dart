import '../../features/auth/domain/user_role.dart';
import '../utils/json_parse.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'];
    final role = roleValue is Map
        ? roleValue['rol'] as String? ?? 'cliente'
        : roleValue as String? ?? 'cliente';

    return UserModel(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: role,
    );
  }

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;

  UserRole get userRole => UserRole.fromApiString(role);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
      };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserModel user;
}

class PaginatedResponse<T> {
  const PaginatedResponse({required this.data, required this.meta});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = parseJsonMapList(json['data'])
        .map(fromJson)
        .toList();
    return PaginatedResponse(
      data: items,
      meta: PaginationMeta.fromJson(
        parseJsonMap(json['meta']) ?? const {},
      ),
    );
  }

  final List<T> data;
  final PaginationMeta meta;
}

class PaginationMeta {
  const PaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: parseJsonInt(json['total']),
      page: parseJsonInt(json['page'], defaultValue: 1),
      limit: parseJsonInt(json['limit'], defaultValue: 20),
      totalPages: parseJsonInt(json['totalPages'], defaultValue: 1),
    );
  }

  final int total;
  final int page;
  final int limit;
  final int totalPages;
}

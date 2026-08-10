enum UserRole {
  cliente,
  comerciante,
  administrador;

  String get title => switch (this) {
        UserRole.cliente => 'App Cliente',
        UserRole.comerciante => 'App Comerciante',
        UserRole.administrador => 'App Administrador',
      };

  String get loginTitle => switch (this) {
        UserRole.cliente => 'Iniciar sesión — Cliente',
        UserRole.comerciante => 'Iniciar sesión — Comerciante',
        UserRole.administrador => 'Iniciar sesión — Administrador',
      };

  String get description => switch (this) {
        UserRole.cliente => 'Buscar comercios, pedir, carrito y seguimiento',
        UserRole.comerciante => 'Pedidos en vivo, productos, ventas y mi local',
        UserRole.administrador =>
          'Comercios, usuarios, reportes y configuración',
      };

  String get apiValue => name;

  static UserRole fromApiString(String role) => switch (role) {
        'administrador' => UserRole.administrador,
        'comerciante' => UserRole.comerciante,
        _ => UserRole.cliente,
      };
}

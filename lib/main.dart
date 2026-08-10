import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'features/auth/presentation/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(PediloApp(authProvider: authProvider));
}

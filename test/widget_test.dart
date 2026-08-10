import 'package:flutter_test/flutter_test.dart';
import 'package:pedidos_app/app.dart';
import 'package:pedidos_app/features/auth/presentation/auth_provider.dart';

void main() {
  testWidgets('App carga sin errores', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    await authProvider.init();

    await tester.pumpWidget(PediloApp(authProvider: authProvider));
    await tester.pump();
    expect(find.text('pedilo'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pedidos_app/core/utils/currency.dart';

void main() {
  test('formats whole and fractional amounts as Uruguayan pesos', () {
    expect(formatUYU(0), 'UYU \$0');
    expect(formatUYU(250), 'UYU \$250');
    expect(formatUYU(12.5), 'UYU \$12.50');
  });
}

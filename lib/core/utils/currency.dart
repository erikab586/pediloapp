String formatUYU(num value) {
  final whole = value == value.roundToDouble();
  final amount = whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return 'UYU \$$amount';
}

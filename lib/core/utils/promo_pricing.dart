import '../../features/cliente/data/models/catalog_models.dart';

/// Resultado del precio de un único producto con su promoción (si tiene).
class PromoPriceResult {
  const PromoPriceResult({
    required this.precioOriginal,
    required this.precioUnitario,
    required this.lineTotal,
    required this.hasPromo,
    this.badgeLabel,
  });

  final double precioOriginal;
  final double precioUnitario;
  final double lineTotal;
  final bool hasPromo;
  final String? badgeLabel;
}

/// Calcula precio solo para el producto que tiene la promo asignada.
/// Otros productos (promo == null) quedan con precio normal.
PromoPriceResult calculatePromoPrice({
  required double unitPrice,
  required int cantidad,
  PromocionModel? promo,
}) {
  final qty = cantidad < 1 ? 1 : cantidad;
  final base = unitPrice < 0 ? 0.0 : unitPrice;

  if (promo == null || !promo.isVigente) {
    return PromoPriceResult(
      precioOriginal: base,
      precioUnitario: base,
      lineTotal: base * qty,
      hasPromo: false,
    );
  }

  final tipo = promo.tipo.trim().toLowerCase();
  double unit = base;
  double line;

  switch (tipo) {
    case 'descuento_porcentual':
    case 'porcentaje':
    case 'liquidacion':
      final pct = promo.valor.clamp(0, 100);
      unit = base * (1 - pct / 100);
      line = unit * qty;
      break;
    case 'descuento_fijo':
    case 'fijo':
      unit = (base - promo.valor).clamp(0, double.infinity);
      line = unit * qty;
      break;
    case 'precio_promocional':
      unit = promo.valor.clamp(0, double.infinity);
      line = unit * qty;
      break;
    case '2x1':
      // Pagás 1 de cada 2.
      final payQty = qty - (qty ~/ 2);
      unit = base;
      line = base * payQty;
      break;
    case '3x2':
      final payQty = qty - (qty ~/ 3);
      unit = base;
      line = base * payQty;
      break;
    case 'n_x_m':
      final n = promo.valor.round().clamp(1, 99);
      final m = (promo.valorSecundario ?? 1).round().clamp(1, n);
      final groups = qty ~/ n;
      final rem = qty % n;
      final payQty = groups * m + rem;
      unit = base;
      line = base * payQty;
      break;
    case 'segunda_unidad_descuento':
      final pct = promo.valor.clamp(0, 100);
      var total = 0.0;
      for (var i = 0; i < qty; i++) {
        if (i % 2 == 1) {
          total += base * (1 - pct / 100);
        } else {
          total += base;
        }
      }
      unit = qty > 0 ? total / qty : base;
      line = total;
      break;
    default:
      // Tipos no numéricos (cupón, horario, etc.): badge sí, precio lista.
      unit = base;
      line = base * qty;
      break;
  }

  return PromoPriceResult(
    precioOriginal: base,
    precioUnitario: _round2(unit),
    lineTotal: _round2(line),
    hasPromo: true,
    badgeLabel: promo.badgeLabel,
  );
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

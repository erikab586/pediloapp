/// Copy / placeholders según rubro (marketplace multi-categoría).
enum RubroKind { comida, farmacia, super_, ferreteria, generico }

RubroKind rubroKindFrom(String? categoriaNombre) {
  final n = (categoriaNombre ?? '').toLowerCase();
  if (n.contains('farmac') || n.contains('salud')) return RubroKind.farmacia;
  if (n.contains('ferreter') || n.contains('construc') || n.contains('herramient')) {
    return RubroKind.ferreteria;
  }
  if (n.contains('super') || n.contains('mercado') || n.contains('almacen')) {
    return RubroKind.super_;
  }
  if (n.contains('rest') ||
      n.contains('comida') ||
      n.contains('cafe') ||
      n.contains('cafetería') ||
      n.contains('cafeteria') ||
      n.contains('pizza') ||
      n.contains('burger') ||
      n.contains('hamburg') ||
      n.contains('helad') ||
      n.contains('panader') ||
      n.contains('bar ')) {
    return RubroKind.comida;
  }
  return RubroKind.generico;
}

String searchPlaceholderForRubro(String? categoriaNombre) {
  return switch (rubroKindFrom(categoriaNombre)) {
    RubroKind.comida => 'Buscar hamburguesas, pizzas, cafés...',
    RubroKind.farmacia => 'Buscar ibuprofeno, vitaminas...',
    RubroKind.super_ => 'Buscar productos del súper...',
    RubroKind.ferreteria => 'Buscar taladro, tornillos, pintura...',
    RubroKind.generico => 'Buscar comida, productos, tiendas...',
  };
}

String menuTabLabelForRubro(String? categoriaNombre) {
  return switch (rubroKindFrom(categoriaNombre)) {
    RubroKind.comida => 'Menú',
    RubroKind.farmacia || RubroKind.super_ || RubroKind.ferreteria => 'Catálogo',
    RubroKind.generico => 'Productos',
  };
}

String addToCartCtaForRubro(String? categoriaNombre, {required String priceLabel}) {
  final verb = switch (rubroKindFrom(categoriaNombre)) {
    RubroKind.comida => 'Agregar',
    RubroKind.farmacia => 'Agregar al pedido',
    RubroKind.ferreteria => 'Consultar / Agregar',
    RubroKind.super_ => 'Agregar',
    RubroKind.generico => 'Agregar',
  };
  return '$verb · $priceLabel';
}

String stickyCartCtaForRubro(String? categoriaNombre) {
  return switch (rubroKindFrom(categoriaNombre)) {
    RubroKind.comida => 'Ver pedido',
    RubroKind.farmacia || RubroKind.super_ => 'Ver carrito',
    RubroKind.ferreteria => 'Ver presupuesto',
    RubroKind.generico => 'Ver pedido',
  };
}

const kDiasSemana = [
  'lunes',
  'martes',
  'miercoles',
  'jueves',
  'viernes',
  'sabado',
  'domingo',
];

const kDiasLabels = {
  'lunes': 'Lunes',
  'martes': 'Martes',
  'miercoles': 'Miércoles',
  'jueves': 'Jueves',
  'viernes': 'Viernes',
  'sabado': 'Sábado',
  'domingo': 'Domingo',
};

String formatHorarios(Map<String, dynamic>? horarios) {
  if (horarios == null || horarios.isEmpty) return '';
  final lines = <String>[];
  for (final d in kDiasSemana) {
    final raw = horarios[d];
    if (raw == null) continue;
    String label;
    if (raw is Map) {
      if (raw['cerrado'] == true) {
        label = 'Cerrado';
      } else {
        final abre = raw['abre']?.toString() ?? '';
        final cierra = raw['cierra']?.toString() ?? '';
        label = (abre.isNotEmpty && cierra.isNotEmpty)
            ? '$abre-$cierra'
            : raw.toString();
      }
    } else {
      label = raw.toString().trim();
      if (label.isEmpty) continue;
    }
    lines.add('${kDiasLabels[d] ?? d}: $label');
  }
  return lines.join('\n');
}

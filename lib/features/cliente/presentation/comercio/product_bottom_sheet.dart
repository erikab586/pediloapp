import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/promo_pricing.dart';
import '../../../../core/utils/rubro_copy.dart';
import '../../data/models/catalog_models.dart';

class ProductSheetExtraQty {
  const ProductSheetExtraQty({required this.extraId, required this.cantidad});

  final int extraId;
  final int cantidad;
}

class ProductSheetResult {
  const ProductSheetResult({
    required this.cantidad,
    this.opcionalId,
    this.extras = const [],
  });

  final int cantidad;
  final int? opcionalId;
  final List<ProductSheetExtraQty> extras;
}

/// Bottom sheet: foto, detalles, opcionales, extras (+qty) → carrito.
Future<ProductSheetResult?> showProductBottomSheet(
  BuildContext context, {
  required ProductoModel producto,
  String? categoriaNombre,
}) {
  return showModalBottomSheet<ProductSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ProductBottomSheet(
      producto: producto,
      categoriaNombre: categoriaNombre,
    ),
  );
}

class _ProductBottomSheet extends StatefulWidget {
  const _ProductBottomSheet({
    required this.producto,
    this.categoriaNombre,
  });

  final ProductoModel producto;
  final String? categoriaNombre;

  @override
  State<_ProductBottomSheet> createState() => _ProductBottomSheetState();
}

class _ProductBottomSheetState extends State<_ProductBottomSheet> {
  int _qty = 1;
  OpcionalModel? _selectedOpcional;
  final Map<int, int> _extraQty = {};

  @override
  void initState() {
    super.initState();
    final ops = widget.producto.opcionalesActivos;
    if (ops.isNotEmpty) {
      _selectedOpcional = ops.first;
    }
  }

  double get _baseUnitPrice =>
      _selectedOpcional?.precio ?? widget.producto.precioValue;

  PromoPriceResult get _promoPrice => calculatePromoPrice(
        unitPrice: _baseUnitPrice,
        cantidad: _qty,
        promo: widget.producto.tienePromocion ? widget.producto.promocion : null,
      );

  double get _extrasTotal {
    var sum = 0.0;
    for (final e in widget.producto.extrasActivos) {
      final q = _extraQty[e.id] ?? 0;
      if (q > 0) sum += e.precio * q;
    }
    return sum;
  }

  /// Promo solo sobre el producto; extras se suman aparte.
  double get _lineTotal => _promoPrice.lineTotal + _extrasTotal;

  void _setExtraQty(int extraId, int qty) {
    setState(() {
      if (qty <= 0) {
        _extraQty.remove(extraId);
      } else {
        _extraQty[extraId] = qty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final detalles = p.detallesActivos;
    final opcionales = p.opcionalesActivos;
    final extras = p.extrasActivos;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: p.imageUrl.isNotEmpty
                            ? Image.network(
                                p.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imageFallback(),
                              )
                            : _imageFallback(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (_promoPrice.hasPromo &&
                        _promoPrice.badgeLabel != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _promoPrice.badgeLabel!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (_promoPrice.hasPromo &&
                        _promoPrice.precioUnitario < _promoPrice.precioOriginal)
                      Row(
                        children: [
                          Text(
                            '\$${_promoPrice.precioUnitario.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${_promoPrice.precioOriginal.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gray400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '\$${_baseUnitPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    if (p.descripcion != null &&
                        p.descripcion!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        p.descripcion!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.gray600,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (opcionales.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Elegí una opción',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...opcionales.map((o) {
                        final selected = _selectedOpcional?.id == o.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? AppColors.yellow.withValues(alpha: 0.35)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setState(() => _selectedOpcional = o),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.navy
                                        : const Color(0xFFE5E7EB),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: AppColors.navy,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.nombre,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          if (o.descripcion != null &&
                                              o.descripcion!
                                                  .trim()
                                                  .isNotEmpty)
                                            Text(
                                              o.descripcion!,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppColors.gray500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      o.precioLabel,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Adicionales',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Sumá lo que quieras; su precio se agrega al total.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...extras.map(_extraTile),
                    ],
                    if (detalles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Detalle del producto',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...detalles.map(_detalleTile),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Cantidad',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const Spacer(),
                        _QtyButton(
                          icon: Icons.remove,
                          onTap:
                              _qty > 1 ? () => setState(() => _qty -= 1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_qty',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _QtyButton(
                          icon: Icons.add,
                          onTap: () => setState(() => _qty += 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (opcionales.isNotEmpty && _selectedOpcional == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Elegí un tamaño o presentación'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final selectedExtras = _extraQty.entries
                    .where((e) => e.value > 0)
                    .map(
                      (e) => ProductSheetExtraQty(
                        extraId: e.key,
                        cantidad: e.value,
                      ),
                    )
                    .toList();
                Navigator.pop(
                  context,
                  ProductSheetResult(
                    cantidad: _qty,
                    opcionalId: _selectedOpcional?.id,
                    extras: selectedExtras,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                addToCartCtaForRubro(
                  widget.categoriaNombre,
                  priceLabel: '\$${_lineTotal.toStringAsFixed(0)}',
                ),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _extraTile(ExtraModel e) {
    final q = _extraQty[e.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: q > 0
            ? AppColors.yellow.withValues(alpha: 0.2)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: q > 0 ? AppColors.navy : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.nombre,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '+ ${e.precioLabel}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          _QtyButton(
            icon: Icons.remove,
            onTap: q > 0 ? () => _setExtraQty(e.id, q - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$q',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _QtyButton(
            icon: Icons.add,
            onTap: () => _setExtraQty(e.id, q + 1),
          ),
        ],
      ),
    );
  }

  Widget _detalleTile(DetalleProductoModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          if (d.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                d.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.titulo,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                if (d.descripcion != null && d.descripcion!.trim().isNotEmpty)
                  Text(
                    d.descripcion!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood_outlined, size: 48, color: AppColors.gray400),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? const Color(0xFFF1F5F9) : AppColors.navy,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? AppColors.gray400 : AppColors.white,
          ),
        ),
      ),
    );
  }
}

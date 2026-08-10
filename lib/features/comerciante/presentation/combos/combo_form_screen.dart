import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../cliente/data/models/catalog_models.dart';
import '../../data/comerciante_repository.dart';

class ComboFormScreen extends StatefulWidget {
  const ComboFormScreen({
    super.key,
    required this.comercio,
    this.combo,
  });

  final ComercioModel comercio;
  final ComboModel? combo;

  bool get isEditing => combo != null;

  @override
  State<ComboFormScreen> createState() => _ComboFormScreenState();
}

class _ComboFormScreenState extends State<ComboFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  late final ComercianteRepository _repository;
  List<ProductoModel> _productos = [];
  final List<_ItemDraft> _items = [];
  bool _activo = true;
  bool _saving = false;
  bool _loadingProductos = true;

  @override
  void initState() {
    super.initState();
    _repository = ComercianteRepository(
      context.read<AuthProvider>().repository.apiClient,
    );
    final c = widget.combo;
    if (c != null) {
      _nombreCtrl.text = c.nombre;
      _descripcionCtrl.text = c.descripcion ?? '';
      _precioCtrl.text = c.precio.toStringAsFixed(0);
      _activo = c.activo;
      _items.addAll(c.items.map(
        (it) => _ItemDraft(
          productoId: it.productoId,
          cantidad: it.cantidad,
          producto: it.producto,
        ),
      ));
    }
    _loadProductos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    try {
      final page = await _repository.getProductos(
        widget.comercio.id,
        soloActivos: false,
      );
      if (!mounted) return;
      setState(() {
        _productos = page.data;
        _loadingProductos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProductos = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _showError('Agregá al menos un producto al combo');
      return;
    }

    setState(() => _saving = true);
    try {
      final items = _items
          .map((it) => ComboItemInput(
                productoId: it.productoId,
                cantidad: it.cantidad,
              ))
          .toList();
      final precio = double.parse(_precioCtrl.text.replaceAll(',', '.'));

      if (widget.isEditing) {
        await _repository.updateCombo(
          id: widget.combo!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          items: items,
        );
      } else {
        await _repository.createCombo(
          comercioId: widget.comercio.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          precio: precio,
          activo: _activo,
          items: items,
        );
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _addItem() async {
    if (_loadingProductos) {
      _showError('Cargando productos, esperá unos segundos');
      return;
    }
    if (_productos.isEmpty) {
      _showError('Necesitás tener productos cargados para crear un combo');
      return;
    }

    final added = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddItemSheet(productos: _productos),
    );
    if (added == null) return;
    setState(() {
      _items
        ..removeWhere((it) => it.productoId == added.productoId)
        ..add(added);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Text(
          widget.isEditing ? 'Editar combo' : 'Nuevo combo',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? 'Guardando…' : 'Guardar',
              style: GoogleFonts.poppins(
                color: AppColors.yellow,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: _loadingProductos
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _label('Nombre'),
                  TextFormField(
                    controller: _nombreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(hint: 'Combo familiar'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresá un nombre'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _label('Descripción (opcional)'),
                  TextFormField(
                    controller: _descripcionCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      hint: '2 pizzas + 2 gaseosas',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('Precio del combo'),
                  TextFormField(
                    controller: _precioCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(
                      hint: '4500',
                      prefix: '\$ ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresá el precio';
                      }
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Precio inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v),
                    title: Text(
                      'Combo activo',
                      style: GoogleFonts.poppins(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Si lo desactivás, no se mostrará a los clientes',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                    activeThumbColor: AppColors.yellow,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Productos del combo',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Aún no agregaste productos. Tocá "Agregar" para empezar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                    )
                  else
                    ..._items.asMap().entries.map(
                          (entry) => _ItemTile(
                            item: entry.value,
                            onChange: (qty) {
                              setState(() {
                                _items[entry.key] = entry.value.copyWith(
                                  cantidad: qty,
                                );
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _items.removeAt(entry.key);
                              });
                            },
                          ),
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gray600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft({
    required this.productoId,
    required this.cantidad,
    this.producto,
  });

  final int productoId;
  int cantidad;
  final ProductoModel? producto;

  _ItemDraft copyWith({int? cantidad}) => _ItemDraft(
        productoId: productoId,
        cantidad: cantidad ?? this.cantidad,
        producto: producto,
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onChange,
    required this.onRemove,
  });

  final _ItemDraft item;
  final ValueChanged<int> onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto?.nombre ?? 'Producto #${item.productoId}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                if (item.producto != null)
                  Text(
                    item.producto!.precioLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.gray500),
            onPressed: () {
              if (item.cantidad > 1) onChange(item.cantidad - 1);
            },
          ),
          Text(
            '${item.cantidad}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.blue),
            onPressed: () => onChange(item.cantidad + 1),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.productos});
  final List<ProductoModel> productos;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  ProductoModel? _selected;
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, mq.viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agregar producto al combo',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductoModel>(
            value: _selected,
            isExpanded: true,
            items: widget.productos
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${p.nombre} · ${p.precioLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Producto',
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (p) => setState(() => _selected = p),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Cantidad'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _cantidad > 1
                    ? () => setState(() => _cantidad -= 1)
                    : null,
              ),
              Text(
                '$_cantidad',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.navy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.blue),
                onPressed: () => setState(() => _cantidad += 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        _ItemDraft(
                          productoId: _selected!.id,
                          cantidad: _cantidad,
                          producto: _selected,
                        ),
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Agregar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

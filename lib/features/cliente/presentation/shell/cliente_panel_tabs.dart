import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/panel/panel_widgets.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_repository.dart';
import '../../data/cliente_repository.dart';
import '../../data/models/catalog_models.dart';

// ─── Buscar ──────────────────────────────────────────────────────────────────

class ClienteSearchTab extends StatefulWidget {
  const ClienteSearchTab({
    super.key,
    required this.catalogRepository,
    required this.onOpenComercio,
  });

  final CatalogRepository catalogRepository;
  final ValueChanged<int> onOpenComercio;

  @override
  State<ClienteSearchTab> createState() => _ClienteSearchTabState();
}

class _ClienteSearchTabState extends State<ClienteSearchTab> {
  final _searchController = TextEditingController();
  List<ComercioModel> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final page = await widget.catalogRepository.getComercios(
        search: query,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _results = page.data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClienteSubHeader(title: 'Buscar'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Comercios, productos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _search,
              ),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : _results.isEmpty
                  ? const EmptyPanelState(
                      icon: Icons.search,
                      title: 'Buscá comercios',
                      subtitle: 'Escribí el nombre de un local o rubro.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final comercio = _results[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SearchResultTile(
                            comercio: comercio,
                            onTap: () => widget.onOpenComercio(comercio.id),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── Carrito ─────────────────────────────────────────────────────────────────

class ClienteCarritoTab extends StatefulWidget {
  const ClienteCarritoTab({
    super.key,
    required this.repository,
    required this.catalogRepository,
    required this.onCartChanged,
    required this.onGoCheckout,
    this.refreshToken = 0,
  });

  final ClienteRepository repository;
  final CatalogRepository catalogRepository;
  final VoidCallback onCartChanged;
  final ValueChanged<int> onGoCheckout;
  final int refreshToken;

  @override
  State<ClienteCarritoTab> createState() => _ClienteCarritoTabState();
}

class _ClienteCarritoTabState extends State<ClienteCarritoTab> {
  CarritoModel? _carrito;
  ComercioModel? _comercio;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClienteCarritoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final carrito = await widget.repository.getCarrito();
      ComercioModel? comercio;
      final comercioId = carrito.resumen.comercioId;
      if (comercioId != null) {
        try {
          comercio = await widget.catalogRepository.getComercio(comercioId);
        } catch (_) {
          // El carrito se muestra igual aunque falle el nombre del comercio.
        }
      }
      if (!mounted) return;
      setState(() {
        _carrito = carrito;
        _comercio = comercio;
        _loading = false;
      });
      widget.onCartChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeErrorEspanol(e);
      });
    }
  }

  Future<void> _updateQty(CarritoItemModel item, int qty) async {
    try {
      if (qty < 1) {
        await widget.repository.removeCarritoItem(item.id);
      } else {
        await widget.repository.updateCarritoItem(item.id, qty);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = _carrito;
    final items = carrito?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClienteSubHeader(title: 'Carrito'),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.5,
                              child: EmptyPanelState(
                                icon: Icons.shopping_cart_outlined,
                                title: _error != null
                                    ? 'No se pudo cargar el carrito'
                                    : 'Carrito vacío',
                                subtitle: _error ??
                                    'Agregá productos desde un comercio.',
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_comercio != null)
                              Text(
                                _comercio!.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              )
                            else if (carrito?.resumen.comercioId != null)
                              Text(
                                'Comercio #${carrito!.resumen.comercioId}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            const SizedBox(height: 12),
                            ...items.map(
                              (item) => _CarritoItemTile(
                                item: item,
                                onMinus: () =>
                                    _updateQty(item, item.cantidad - 1),
                                onPlus: () =>
                                    _updateQty(item, item.cantidad + 1),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SummaryRow(
                              label: 'Subtotal',
                              value:
                                  '\$${carrito!.resumen.subtotal.toStringAsFixed(0)}',
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: carrito.resumen.comercioId == null
                                  ? null
                                  : () => widget.onGoCheckout(
                                        carrito.resumen.comercioId!,
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.yellow,
                                foregroundColor: AppColors.navy,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Confirmar pedido · \$${carrito.resumen.total.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}

class _CarritoItemTile extends StatelessWidget {
  const _CarritoItemTile({
    required this.item,
    required this.onMinus,
    required this.onPlus,
  });

  final CarritoItemModel item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  item.lineTotalLabel,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(onPressed: onMinus, icon: const Icon(Icons.remove)),
              Text('${item.cantidad}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              IconButton(onPressed: onPlus, icon: const Icon(Icons.add)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppColors.gray600)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

// ─── Pedidos ─────────────────────────────────────────────────────────────────

class ClientePedidosTab extends StatefulWidget {
  const ClientePedidosTab({
    super.key,
    required this.repository,
    required this.onOpenTracking,
    this.refreshToken = 0,
  });

  final ClienteRepository repository;
  final ValueChanged<int> onOpenTracking;
  final int refreshToken;

  @override
  State<ClientePedidosTab> createState() => _ClientePedidosTabState();
}

class _ClientePedidosTabState extends State<ClientePedidosTab> {
  static const _filters = ['Activos', 'Historial'];

  int _filterIndex = 0;
  List<ClientePedidoModel> _allPedidos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClientePedidosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getPedidos(limit: 50);
      if (!mounted) return;
      setState(() {
        _allPedidos = page.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeErrorEspanol(e);
      });
    }
  }

  List<ClientePedidoModel> get _pedidos {
    return switch (_filterIndex) {
      0 => _allPedidos.where((p) => p.isActive).toList(),
      _ => _allPedidos.where((p) => !p.isActive).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = _pedidos;
    final emptyTitle = _error != null
        ? 'No se pudieron cargar los pedidos'
        : _filterIndex == 0
            ? 'Sin pedidos activos'
            : 'Sin pedidos en el historial';
    final emptySubtitle = _error ??
        (_filterIndex == 0
            ? 'Los pedidos en curso aparecen acá. Revisá Historial si ya fueron entregados o cancelados.'
            : 'Acá aparecen pedidos entregados o cancelados.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClienteSubHeader(title: 'Mis pedidos'),
        FilterChips(
          labels: _filters,
          selectedIndex: _filterIndex,
          onSelected: (i) => setState(() => _filterIndex = i),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                )
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: pedidos.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.45,
                              child: EmptyPanelState(
                                icon: Icons.receipt_long_outlined,
                                title: emptyTitle,
                                subtitle: emptySubtitle,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: pedidos.length,
                          itemBuilder: (context, index) {
                            final pedido = pedidos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PedidoClienteCard(
                                pedido: pedido,
                                onTap: () =>
                                    widget.onOpenTracking(pedido.id),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _PedidoClienteCard extends StatelessWidget {
  const _PedidoClienteCard({required this.pedido, required this.onTap});

  final ClientePedidoModel pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.comercioNombre ?? 'Pedido #${pedido.id}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      pedido.status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                pedido.totalLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Perfil ──────────────────────────────────────────────────────────────────

class ClientePerfilTab extends StatelessWidget {
  const ClientePerfilTab({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final ClienteRepository repository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClienteSubHeader(title: 'Perfil'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.yellow,
                      child: Text(
                        auth.user?.name.isNotEmpty == true
                            ? auth.user!.name[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.name ?? 'Cliente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            auth.user?.email ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PerfilTile(
                icon: Icons.location_on_outlined,
                label: 'Mis direcciones',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClienteDireccionesScreen(repository: repository),
                    ),
                  );
                },
              ),
              _PerfilTile(
                icon: Icons.favorite_border,
                label: 'Favoritos',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClienteFavoritosScreen(repository: repository),
                    ),
                  );
                },
              ),
              _PerfilTile(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                destructive: true,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerfilTile extends StatelessWidget {
  const _PerfilTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: destructive ? const Color(0xFFEF4444) : AppColors.navy,
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: destructive ? const Color(0xFFEF4444) : AppColors.navy,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
        onTap: onTap,
      ),
    );
  }
}

class _ClienteSubHeader extends StatelessWidget {
  const _ClienteSubHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        12,
      ),
      color: AppColors.navy,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// ─── Direcciones ─────────────────────────────────────────────────────────────

class ClienteDireccionesScreen extends StatefulWidget {
  const ClienteDireccionesScreen({super.key, required this.repository});

  final ClienteRepository repository;

  @override
  State<ClienteDireccionesScreen> createState() =>
      _ClienteDireccionesScreenState();
}

class _ClienteDireccionesScreenState extends State<ClienteDireccionesScreen> {
  List<DireccionModel> _direcciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.getDirecciones();
      if (!mounted) return;
      setState(() {
        _direcciones = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva dirección'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Calle, número, ciudad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;

    try {
      await widget.repository.createDireccion(
        tipo: 'Casa',
        direccion: ctrl.text.trim(),
        predeterminada: _direcciones.isEmpty,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      await mostrarAlertaError(context, mensaje: mensajeErrorEspanol(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis direcciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.navy,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _direcciones.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.location_on_outlined,
                  title: 'Sin direcciones',
                  subtitle: 'Agregá una dirección para delivery.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _direcciones.length,
                  itemBuilder: (context, index) {
                    final d = _direcciones[index];
                    return ListTile(
                      title: Text(d.direccion),
                      subtitle: Text(d.tipo),
                      trailing: d.predeterminada
                          ? const Icon(Icons.star, color: AppColors.yellow)
                          : null,
                    );
                  },
                ),
    );
  }
}

class ClienteFavoritosScreen extends StatefulWidget {
  const ClienteFavoritosScreen({super.key, required this.repository});

  final ClienteRepository repository;

  @override
  State<ClienteFavoritosScreen> createState() => _ClienteFavoritosScreenState();
}

class _ClienteFavoritosScreenState extends State<ClienteFavoritosScreen> {
  List<ComercioModel> _favoritos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.getFavoritosComercios();
      if (!mounted) return;
      setState(() {
        _favoritos = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            )
          : _favoritos.isEmpty
              ? const EmptyPanelState(
                  icon: Icons.favorite_border,
                  title: 'Sin favoritos',
                  subtitle: 'Marcá comercios con el corazón.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoritos.length,
                  itemBuilder: (context, index) {
                    final c = _favoritos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SearchResultTile(
                        comercio: c,
                        onTap: () => context.push('/cliente/comercio/${c.id}'),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.comercio, required this.onTap});

  final ComercioModel comercio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: comercio.imageUrl.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.store, color: AppColors.gray400),
                      )
                    : Image.network(
                        comercio.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.store, color: AppColors.gray400),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comercio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      comercio.categoryLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                comercio.estaAbierto ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: comercio.estaAbierto ? AppColors.green : AppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

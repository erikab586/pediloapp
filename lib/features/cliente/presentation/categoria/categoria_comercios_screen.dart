import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_mock_data.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/catalog_models.dart';
import '../widgets/cliente_widgets.dart';

/// Lista de comercios de una categoría (ej. Restaurantes).
class CategoriaComerciosScreen extends StatefulWidget {
  const CategoriaComerciosScreen({
    super.key,
    required this.categoriaId,
    this.categoriaNombre,
  });

  final int categoriaId;
  final String? categoriaNombre;

  @override
  State<CategoriaComerciosScreen> createState() =>
      _CategoriaComerciosScreenState();
}

class _CategoriaComerciosScreenState extends State<CategoriaComerciosScreen> {
  late final CatalogRepository _catalog;
  final _searchController = TextEditingController();

  List<ComercioModel> _comercios = [];
  Map<int, String> _promoBadges = {};
  bool _loading = true;
  String? _error;
  String _query = '';

  String get _title {
    final name = widget.categoriaNombre?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Categoría';
  }

  List<ComercioModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _comercios;
    return _comercios
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.categoryLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().repository.apiClient;
    _catalog = CatalogRepository(api);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _catalog.getComercios(
        categoriaId: widget.categoriaId,
        limit: 100,
      );
      final comercios = result.data;
      final promoBadges = <int, String>{};
      await Future.wait(
        comercios.take(20).map((c) async {
          try {
            final promos = await _catalog.getPromociones(c.id);
            final activas = promos.where((p) => p.activo).toList();
            if (activas.isNotEmpty) {
              promoBadges[c.id] = activas.first.badgeLabel;
            }
          } catch (_) {}
        }),
      );
      if (!mounted) return;
      setState(() {
        _comercios = comercios;
        _promoBadges = promoBadges;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = CatalogMockData.fallbackComercios
          .where(
            (c) =>
                c.categoriaId == widget.categoriaId ||
                (widget.categoriaNombre != null &&
                    c.categoriaNombre?.toLowerCase() ==
                        widget.categoriaNombre!.toLowerCase()),
          )
          .toList();
      setState(() {
        _comercios = fallback.isNotEmpty
            ? fallback
            : CatalogMockData.fallbackComercios;
        _loading = false;
        _error = fallback.isEmpty ? 'No se pudo cargar. Mostrando demo.' : null;
      });
    }
  }

  void _openComercio(int id) {
    context.push('/cliente/comercio/$id');
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final abiertos = items.where((c) => c.estaAbierto).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (!_loading)
              Text(
                items.isEmpty
                    ? 'Sin locales'
                    : '$abiertos abiertos · ${items.length} locales',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray500,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
              decoration: InputDecoration(
                hintText: 'Buscar en $_title...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: StoresSectionSkeleton(),
                  )
                : RefreshIndicator(
                    color: AppColors.yellow,
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              EmptyActionState(
                                icon: Icons.storefront_outlined,
                                title: 'Sin locales en esta categoría',
                                subtitle:
                                    'Todavía no hay comercios en $_title. Probá otra categoría.',
                                actionLabel: 'Volver',
                                onAction: () => context.pop(),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              ComercioMarketplaceList(
                                comercios: items,
                                promoBadges: _promoBadges,
                                onOpen: _openComercio,
                              ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

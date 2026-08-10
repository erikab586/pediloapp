import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pedilo_logo.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/catalog_mock_data.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/catalog_models.dart';
import '../widgets/cliente_widgets.dart';

class ClienteHomeTab extends StatefulWidget {
  const ClienteHomeTab({
    super.key,
    required this.catalogRepository,
    required this.onOpenComercio,
    this.onGoSearch,
  });

  final CatalogRepository catalogRepository;
  final ValueChanged<int> onOpenComercio;
  final VoidCallback? onGoSearch;

  @override
  State<ClienteHomeTab> createState() => _ClienteHomeTabState();
}

class _ClienteHomeTabState extends State<ClienteHomeTab> {
  List<CategoriaModel> _categorias = [];
  List<ComercioModel> _comercios = [];
  int? _selectedCategoriaId;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({int? categoriaId}) async {
    setState(() => _loading = true);
    try {
      final categoriasResult =
          await widget.catalogRepository.getCategorias(limit: 10);
      final comerciosResult = await widget.catalogRepository.getComercios(
        limit: 10,
        categoriaId: categoriaId,
      );
      if (!mounted) return;
      setState(() {
        _categorias = categoriasResult.data;
        _comercios = comerciosResult.data;
        _loadError = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categorias = CatalogMockData.fallbackCategorias;
        _comercios = CatalogMockData.fallbackComercios;
        _loadError = 'No se pudo conectar con la API. Mostrando datos de ejemplo.';
        _loading = false;
      });
    }
  }

  void _onCategoryTap(int? categoriaId) {
    setState(() => _selectedCategoriaId = categoriaId);
    _loadData(categoriaId: categoriaId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _HomeHeader(userName: auth.user?.name),
          const _LocationBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                : RefreshIndicator(
                    color: AppColors.yellow,
                    onRefresh: () =>
                        _loadData(categoriaId: _selectedCategoriaId),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (_loadError != null) _ApiBanner(message: _loadError!),
                        _HeroBanner(onTapSearch: widget.onGoSearch),
                        const SizedBox(height: 8),
                        if (_categorias.isNotEmpty)
                          _CategoriesRow(
                            categorias: _categorias,
                            selectedId: _selectedCategoriaId,
                            onTap: _onCategoryTap,
                          ),
                        const SizedBox(height: 8),
                        const _SectionHeader(
                          title: 'Locales destacados',
                          action: 'Ver todos',
                        ),
                        const SizedBox(height: 12),
                        if (_comercios.isEmpty)
                          const _EmptyComerciosBanner()
                        else
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _comercios.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final comercio = _comercios[index];
                                return StoreCard(
                                  comercio: comercio,
                                  onTap: () =>
                                      widget.onOpenComercio(comercio.id),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        const _PromoBanner(),
                        const SizedBox(height: 16),
                        const _FeaturesFooter(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Expanded(
            child: Center(
              child: PediloLogo(height: 32, textColor: AppColors.navy),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  const _LocationBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.yellow, size: 18),
          const SizedBox(width: 6),
          Text(
            'Montevideo, Uruguay',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiBanner extends StatelessWidget {
  const _ApiBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.navy),
      ),
    );
  }
}

class _EmptyComerciosBanner extends StatelessWidget {
  const _EmptyComerciosBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.store_outlined, size: 40, color: AppColors.gray400),
          const SizedBox(height: 12),
          Text(
            'Aún no hay comercios publicados',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({this.onTapSearch});

  final VoidCallback? onTapSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descubrí los mejores comercios cerca tuyo.',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onTapSearch,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.gray400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buscar comida, productos, tiendas...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.gray400,
                      ),
                    ),
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

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow({
    required this.categorias,
    required this.selectedId,
    required this.onTap,
  });

  final List<CategoriaModel> categorias;
  final int? selectedId;
  final ValueChanged<int?> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          CategoryItem(
            label: 'Todos',
            emoji: '🏠',
            selected: selectedId == null,
            onTap: () => onTap(null),
          ),
          ...categorias.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: CategoryItem(
                label: cat.nombreCategoria,
                emoji: CatalogMockData.emojiForCategory(cat.nombreCategoria),
                imageUrl: cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
                selected: selectedId == cat.id,
                onTap: () => onTap(cat.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '20% OFF en tu primera compra',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PEDILO20',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF1B2838),
            child: Text('🍔', style: TextStyle(fontSize: 32)),
          ),
        ],
      ),
    );
  }
}

class _FeaturesFooter extends StatelessWidget {
  const _FeaturesFooter();

  static const _features = [
    ('📍', 'Comercios cerca tuyo'),
    ('🛵', 'Seguimiento en vivo'),
    ('💳', 'Pagos seguros'),
    ('🏷️', 'Promos exclusivas'),
    ('🎧', 'Soporte 24/7'),
    ('❤️', 'Favoritos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: _features
            .map(
              (item) => Column(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

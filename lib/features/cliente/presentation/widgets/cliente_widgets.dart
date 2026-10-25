import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/catalog_mock_data.dart';
import '../../data/models/catalog_models.dart';

/// Colores de fondo para tiles de categoría.
abstract final class CategoryPalette {
  static const List<Color> base = [
    Color(0xFFFFC83D),
    Color(0xFF0D1B2A),
    Color(0xFF2563EB),
    Color(0xFF22C55E),
    Color(0xFFFF9500),
    Color(0xFF6CACE7),
    Color(0xFF00C853),
  ];

  static Color tileBackground(int index) {
    return base[index % base.length];
  }
}

/// Matriz 3×3 de categorías con subtítulo y acceso a más.
class CategoryMatrixSection extends StatelessWidget {
  const CategoryMatrixSection({
    super.key,
    required this.categorias,
    required this.selectedId,
    required this.onTap,
    required this.onMore,
    this.maxVisible = 9,
  });

  final List<CategoriaModel> categorias;
  final int? selectedId;
  final ValueChanged<int?> onTap;
  final VoidCallback onMore;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = categorias.take(maxVisible).toList();
    final hasMore = categorias.length > maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Categorías',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: hasMore
                    ? _CategoryMoreButton(onTap: onMore)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sin categorías disponibles',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.96,
            ),
            itemBuilder: (context, index) {
              final cat = visible[index];
              return CategoryGridTile(
                label: cat.nombreCategoria,
                emoji: CatalogMockData.emojiForCategory(cat.nombreCategoria),
                imageUrl: cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
                backgroundColor: CategoryPalette.tileBackground(index),
                selected: selectedId == cat.id,
                onTap: () => onTap(cat.id),
              );
            },
          ),
      ],
    );
  }
}

class _CategoryMoreButton extends StatelessWidget {
  const _CategoryMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Más',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: AppColors.gray600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile cuadrado con imagen y título (estilo marketplace).
class CategoryGridTile extends StatelessWidget {
  const CategoryGridTile({
    super.key,
    required this.label,
    required this.emoji,
    required this.backgroundColor,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  final String label;
  final String emoji;
  final Color backgroundColor;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.72,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: AppColors.yellow, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _CategoryTileContent(
                      imageUrl: imageUrl,
                      emoji: emoji,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTileContent extends StatelessWidget {
  const _CategoryTileContent({
    required this.emoji,
    this.imageUrl,
  });

  final String emoji;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Image.network(
            imageUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}

/// Lista vertical de comercios (favoritos, destacados, todos).
class ComercioMarketplaceList extends StatelessWidget {
  const ComercioMarketplaceList({
    super.key,
    required this.comercios,
    required this.onOpen,
    this.promoBadges = const {},
    this.spacing = 12,
  });

  final List<ComercioModel> comercios;
  final ValueChanged<int> onOpen;
  final Map<int, String> promoBadges;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < comercios.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          ComercioMarketplaceTile(
            comercio: comercios[i],
            promoBadge: promoBadges[comercios[i].id],
            onTap: () => onOpen(comercios[i].id),
          ),
        ],
      ],
    );
  }
}

/// Card horizontal de comercio (referencia marketplace).
class ComercioMarketplaceTile extends StatelessWidget {
  const ComercioMarketplaceTile({
    super.key,
    required this.comercio,
    required this.onTap,
    this.promoBadge,
    this.rating,
    this.reviewCount,
    this.etaLabel,
    this.minAmount,
  });

  static const _detailIconColor = Color(0xFFA85D4A);

  final ComercioModel comercio;
  final VoidCallback onTap;
  final String? promoBadge;
  final double? rating;
  final int? reviewCount;
  final String? etaLabel;
  final int? minAmount;

  @override
  Widget build(BuildContext context) {
    final logoUrl = comercio.logoUrl.isNotEmpty
        ? comercio.logoUrl
        : comercio.imageUrl;
    final displayRating = rating ?? 4.6 + (comercio.id % 5) * 0.05;
    final displayReviews = reviewCount ?? 120 + (comercio.id * 53) % 800;
    final eta = etaLabel ?? comercio.etaLabel ?? _etaFor(comercio.id);
    final minLabel = minAmount != null
        ? '\$$minAmount'
        : (comercio.montoMinimoLabel ??
            '\$${150 + (comercio.id % 4) * 50}');
    final payment = 'POS';
    final abierto = comercio.estaAbierto;

    return Material(
      color: AppColors.white,
      elevation: 1.5,
      shadowColor: AppColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ComercioLogoFallback(name: comercio.name),
                        )
                      : _ComercioLogoFallback(name: comercio.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            comercio.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _OpenStatusBadge(abierto: abierto),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 17,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($displayReviews)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _MarketplaceDetailRow(
                      icon: Icons.credit_card_outlined,
                      child: Text(
                        payment,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _MarketplaceDetailRow(
                      icon: Icons.schedule_outlined,
                      child: Text(
                        eta,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _MarketplaceDetailRow(
                      icon: Icons.attach_money_rounded,
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                          children: [
                            const TextSpan(text: 'Monto mínimo: '),
                            TextSpan(
                              text: minLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (promoBadge != null && promoBadge!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          promoBadge!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _etaFor(int id) {
    const slots = [
      '25 - 40 minutos',
      '30 - 45 minutos',
      '40 - 60 minutos',
    ];
    return slots[id % slots.length];
  }
}

class _OpenStatusBadge extends StatelessWidget {
  const _OpenStatusBadge({required this.abierto});

  final bool abierto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: abierto ? AppColors.green : AppColors.gray400,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        abierto ? 'Abierto' : 'Cerrado',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _MarketplaceDetailRow extends StatelessWidget {
  const _MarketplaceDetailRow({
    required this.icon,
    required this.child,
  });

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: ComercioMarketplaceTile._detailIconColor,
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _ComercioLogoFallback extends StatelessWidget {
  const _ComercioLogoFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.gray400,
        ),
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.comercio,
    this.onTap,
    this.rating,
    this.promoBadge,
    this.etaLabel,
  });

  final ComercioModel comercio;
  final VoidCallback? onTap;
  final double? rating;
  final String? promoBadge;
  final String? etaLabel;

  @override
  Widget build(BuildContext context) {
    final abierto = comercio.estaAbierto;
    final displayRating = rating ?? 4.6 + (comercio.id % 5) * 0.05;
    final eta = etaLabel ?? comercio.etaLabel ?? '25-40 min';

    return SizedBox(
      width: 168,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shadowColor: AppColors.navy.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: abierto ? 1 : 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.55,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: abierto
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                        child: _StoreImage(
                          url: comercio.imageUrl.isNotEmpty
                              ? comercio.imageUrl
                              : comercio.logoUrl,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _StatusChip(abierto: abierto),
                      ),
                      if (promoBadge != null && promoBadge!.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _PromoChip(label: promoBadge!),
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _RatingChip(rating: displayRating),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comercio.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${comercio.categoryLabel} · $eta',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.gray500,
                        ),
                      ),
                      if (!abierto) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ver menú · Pedí más tarde',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  const _StoreImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.store, color: AppColors.gray400, size: 40),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.store, color: AppColors.gray400, size: 40),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.abierto});

  final bool abierto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: abierto ? AppColors.green : AppColors.gray500,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        abierto ? 'Abierto' : 'Cerrado',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _PromoChip extends StatelessWidget {
  const _PromoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.yellow),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  const CategoryItem({
    super.key,
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.icon,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected ? AppColors.yellow : AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: icon != null
                ? Icon(icon, color: AppColors.navy, size: 24)
                : imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text(emoji, style: const TextStyle(fontSize: 24)),
                      )
                    : Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClienteBottomNav extends StatelessWidget {
  const ClienteBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.search,
                label: 'Buscar',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.shopping_cart_outlined,
                label: 'Carrito',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                badge: cartCount > 0 ? '$cartCount' : null,
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Pedidos',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.yellow : AppColors.gray400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

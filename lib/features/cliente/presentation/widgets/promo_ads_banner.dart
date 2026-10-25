import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Slide de publicidad (luego vendrá del panel admin).
class PromoAdSlide {
  const PromoAdSlide({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkUrl,
  });

  final int id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? linkUrl;
}

/// Defaults hasta que el admin configure banners.
abstract final class PromoAdDefaults {
  static const List<PromoAdSlide> slides = [
    PromoAdSlide(
      id: 1,
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=900&h=400&fit=crop',
      title: 'Pedí lo que más te gusta',
      subtitle: 'Comida, café y más cerca tuyo',
    ),
    PromoAdSlide(
      id: 2,
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=900&h=400&fit=crop',
      title: 'Promos de la semana',
      subtitle: 'Descuentos en tus locales favoritos',
    ),
    PromoAdSlide(
      id: 3,
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=900&h=400&fit=crop',
      title: 'Entrega rápida',
      subtitle: 'Tu pedido en minutos',
    ),
  ];
}

/// Banner de publicidad navy (mismo lenguaje visual que cupones).
/// Auto-avanza cada [autoPlayInterval].
class PromoAdsBanner extends StatefulWidget {
  const PromoAdsBanner({
    super.key,
    this.slides,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.height = 140,
  });

  final List<PromoAdSlide>? slides;
  final Duration autoPlayInterval;
  final double height;

  @override
  State<PromoAdsBanner> createState() => _PromoAdsBannerState();
}

class _PromoAdsBannerState extends State<PromoAdsBanner> {
  late final PageController _controller;
  int _page = 0;
  Timer? _timer;

  List<PromoAdSlide> get _items {
    final slides = widget.slides;
    if (slides != null && slides.isNotEmpty) return slides;
    return PromoAdDefaults.slides;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant PromoAdsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides != widget.slides ||
        oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    final items = _items;
    if (items.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) => _PromoAdSlideCard(
              slide: items[index],
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 14 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active ? AppColors.yellow : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoAdSlideCard extends StatelessWidget {
  const _PromoAdSlideCard({required this.slide});

  final PromoAdSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            slide.imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _FallbackArt(slide: slide),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const ColoredBox(
                color: AppColors.navy,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              );
            },
          ),
          // Degradado navy para legibilidad del texto (mismo color de cupón).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.navy.withValues(alpha: 0.88),
                  AppColors.navy.withValues(alpha: 0.45),
                  AppColors.navy.withValues(alpha: 0.15),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (slide.title != null && slide.title!.isNotEmpty)
                    Text(
                      slide.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                        height: 1.15,
                      ),
                    ),
                  if (slide.subtitle != null &&
                      slide.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      slide.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.white.withValues(alpha: 0.88),
                        height: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ver más',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
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

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.slide});

  final PromoAdSlide slide;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                slide.title ?? 'Publicidad pedilo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
            const Icon(
              Icons.campaign_rounded,
              color: AppColors.yellow,
              size: 48,
            ),
          ],
        ),
      ),
    );
  }
}

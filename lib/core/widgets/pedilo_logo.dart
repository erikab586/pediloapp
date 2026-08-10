import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Logo de pedilo según identidad visual oficial.
class PediloLogo extends StatelessWidget {
  const PediloLogo({
    super.key,
    this.height = 48,
    this.showText = true,
    this.textColor = AppColors.navy,
    this.useAsset = true,
  });

  final double height;
  final bool showText;
  final Color textColor;
  final bool useAsset;

  static const _assetPath = 'assets/images/pedilo.jpeg';

  @override
  Widget build(BuildContext context) {
    if (useAsset) {
      return Image.asset(
        _assetPath,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _BrandLogo(
          height: height,
          showText: showText,
          textColor: textColor,
        ),
      );
    }

    return _BrandLogo(
      height: height,
      showText: showText,
      textColor: textColor,
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.height,
    required this.showText,
    required this.textColor,
  });

  final double height;
  final bool showText;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final iconSize = height * 0.85;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize * 1.1,
          height: iconSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _speedLine(iconSize * 0.42),
                    SizedBox(height: iconSize * 0.06),
                    _speedLine(iconSize * 0.55),
                    SizedBox(height: iconSize * 0.06),
                    _speedLine(iconSize * 0.34),
                  ],
                ),
              ),
              Positioned(
                left: iconSize * 0.22,
                child: Text(
                  'P',
                  style: GoogleFonts.poppins(
                    fontSize: iconSize * 0.72,
                    fontWeight: FontWeight.w700,
                    color: AppColors.yellow,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(width: height * 0.12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'ped',
                  style: GoogleFonts.poppins(
                    fontSize: height * 0.52,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'i',
                  style: GoogleFonts.poppins(
                    fontSize: height * 0.52,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                TextSpan(
                  text: '•',
                  style: GoogleFonts.poppins(
                    fontSize: height * 0.52,
                    fontWeight: FontWeight.w700,
                    color: AppColors.yellow,
                  ),
                ),
                TextSpan(
                  text: 'lo',
                  style: GoogleFonts.poppins(
                    fontSize: height * 0.52,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _speedLine(double width) {
    return Container(
      width: width,
      height: height * 0.07,
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

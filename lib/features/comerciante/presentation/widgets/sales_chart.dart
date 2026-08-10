import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/comerciante_repository.dart';

class SalesBarChart extends StatelessWidget {
  const SalesBarChart({
    super.key,
    required this.data,
    this.title = 'Ventas por día',
  });

  final List<DailyStatModel> data;
  final String title;

  @override
  Widget build(BuildContext context) {
    final recent = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Sin datos de ventas aún',
            style: GoogleFonts.poppins(color: AppColors.gray500),
          ),
        ),
      );
    }

    final maxVal = recent
        .map((d) => d.totalVentas)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((day) {
                final heightFactor =
                    maxVal > 0 ? day.totalVentas / maxVal : 0.0;
                final label = day.fecha.length >= 5
                    ? day.fecha.substring(5)
                    : day.fecha;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '\$${day.totalVentas.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 80 * heightFactor + 4,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

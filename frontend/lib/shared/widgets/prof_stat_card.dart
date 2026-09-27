import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfStatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final bool deltaPositive;
  final Color? accentColor;

  const ProfStatCard({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.deltaPositive = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final topBorderColor = accentColor ?? AppColors.marginRule;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r6),
        border: Border.all(color: AppColors.marginRule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Semantic top border
          Container(
            height: 2,
            width: 32,
            color: topBorderColor,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: AppColors.inkPrimary,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: deltaPositive ? AppColors.verified : AppColors.feedbackRed,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

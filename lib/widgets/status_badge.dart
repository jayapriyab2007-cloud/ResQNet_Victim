import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class PriorityBadge extends StatelessWidget {
  final int level;
  final String label;

  const PriorityBadge({
    super.key,
    required this.level,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = switch (level) {
      1 => (AppColors.emergencyRed, AppColors.emergencyRedBg, AppColors.emergencyRed.withValues(alpha: 0.5)),
      2 => (AppColors.warningAmber, AppColors.warningAmberBg, AppColors.warningAmber.withValues(alpha: 0.5)),
      3 => (AppColors.infoBlue, AppColors.infoBlueBg, AppColors.infoBlue.withValues(alpha: 0.5)),
      _ => (AppColors.textSecondary, AppColors.surfaceElevated, AppColors.border),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'P$level • $label',
        style: AppTextStyles.labelCaps.copyWith(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SimulationBadge extends StatelessWidget {
  const SimulationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.infoBlueBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 12, color: AppColors.infoBlue),
          const SizedBox(width: 4),
          Text(
            'SIMULATION MODE',
            style: AppTextStyles.labelCaps.copyWith(
              color: AppColors.infoBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionIndicator extends StatelessWidget {
  final String status; // 'ONLINE', 'OFFLINE', 'MESH CONNECTED', 'SIMULATION MODE'

  const ConnectionIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (dotColor, textColor, textBg) = switch (status.toUpperCase()) {
      'ONLINE' => (AppColors.successGreen, AppColors.successGreen, AppColors.successGreenBg),
      'MESH CONNECTED' => (AppColors.infoBlue, AppColors.infoBlue, AppColors.infoBlueBg),
      'SIMULATION MODE' => (AppColors.infoBlue, AppColors.infoBlue, AppColors.infoBlueBg),
      _ => (AppColors.warningAmber, AppColors.warningAmber, AppColors.warningAmberBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dotColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: AppTextStyles.labelCaps.copyWith(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

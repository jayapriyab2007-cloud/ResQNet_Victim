import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class StatusStrip extends StatelessWidget {
  final bool gpsActive;
  final bool meshActive;
  final int nodeCount;
  final int batteryLevel;

  const StatusStrip({
    super.key,
    this.gpsActive = true,
    this.meshActive = true,
    this.nodeCount = 3,
    this.batteryLevel = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          children: [
            Expanded(
              child: _StripStat(
                label: 'GPS',
                value: gpsActive ? 'OK' : 'OFF',
                valueColor: gpsActive ? AppColors.successGreen : AppColors.warningAmber,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _StripStat(
                label: 'MESH',
                value: meshActive ? 'LIVE' : 'SEEK',
                valueColor: meshActive ? AppColors.successGreen : AppColors.warningAmber,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _StripStat(
                label: 'NODES',
                value: '$nodeCount',
                valueColor: nodeCount > 0 ? AppColors.successGreen : AppColors.warningAmber,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _StripStat(
                label: 'BATT',
                value: '$batteryLevel%',
                valueColor: batteryLevel > 30
                    ? AppColors.successGreen
                    : batteryLevel > 15
                        ? AppColors.warningAmber
                        : AppColors.emergencyRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StripStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.labelCaps.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.numericStat.copyWith(color: valueColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

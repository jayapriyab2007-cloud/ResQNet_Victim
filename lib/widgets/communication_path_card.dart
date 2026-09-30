import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class CommunicationPathCard extends StatelessWidget {
  final int currentStage; // 0..6 active highlight

  const CommunicationPathCard({
    super.key,
    this.currentStage = 0,
  });

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        icon: Icons.phone_android,
        title: 'Victim Phone',
        subtitle: 'Stores SOS offline & encodes compact packet',
        stage: 0,
      ),
      (
        icon: Icons.bluetooth,
        title: 'BLE Link',
        subtitle: 'Hands packet to local handheld device',
        stage: 1,
      ),
      (
        icon: Icons.cell_tower,
        title: 'LoRa Handheld',
        subtitle: 'Sub-GHz radio bridge (ESP32 + SX1262)',
        stage: 2,
      ),
      (
        icon: Icons.hub,
        title: 'LoRa Multi-Hop Mesh',
        subtitle: 'Relays device-to-device across disaster zone',
        stage: 3,
      ),
      (
        icon: Icons.router,
        title: 'ResQNet Gateway',
        subtitle: 'Receives packet at perimeter network edge',
        stage: 4,
      ),
      (
        icon: Icons.cloud_done,
        title: 'FastAPI Backend',
        subtitle: 'Deduplicates & enriches with medical profile',
        stage: 5,
      ),
      (
        icon: Icons.shield,
        title: 'Responder Command Center',
        subtitle: 'Dispatches rescue units based on priority & location',
        stage: 6,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: AppColors.infoBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'EMERGENCY COMMUNICATION PATH',
                style: AppTextStyles.labelCaps.copyWith(
                  color: AppColors.infoBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++) ...[
            _PathStepRow(
              icon: steps[i].icon,
              title: steps[i].title,
              subtitle: steps[i].subtitle,
              isActive: i <= currentStage,
              isCurrent: i == currentStage,
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Container(
                  width: 2,
                  height: 18,
                  color: i < currentStage ? AppColors.successGreen : AppColors.border,
                ),
              ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoBlueBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.infoBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No cellular or internet required for the initial 4 hops. The mesh routes around network outages.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathStepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isCurrent;

  const _PathStepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (isCurrent ? AppColors.emergencyRed : AppColors.successGreenBg)
                : AppColors.surfaceElevated,
            border: Border.all(
              color: isActive
                  ? (isCurrent ? AppColors.emergencyRed : AppColors.successGreen)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? (isCurrent ? Colors.white : AppColors.successGreen)
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class EmergencyTimeline extends StatelessWidget {
  final int stage; // 0..6

  const EmergencyTimeline({super.key, required this.stage});

  static const stages = [
    'Request Created',
    'GPS Location Captured',
    'BLE Transmission',
    'LoRa Mesh Relaying',
    'Gateway Confirmation',
    'Responder Notification',
    'Responder Assigned',
  ];

  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DELIVERY TIMELINE',
                style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '${stage + 1} / ${stages.length}',
                style: AppTextStyles.labelCaps.copyWith(
                  color: stage >= 5 ? AppColors.successGreen : AppColors.infoBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < stages.length; i++) ...[
            _TimelineItem(
              index: i,
              title: stages[i],
              isDone: i < stage,
              isCurrent: i == stage,
              isLast: i == stages.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final int index;
  final String title;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _TimelineItem({
    required this.index,
    required this.title,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppColors.successGreenBg
                    : isCurrent
                        ? AppColors.infoBlueBg
                        : AppColors.surfaceElevated,
                border: Border.all(
                  color: isDone
                      ? AppColors.successGreen
                      : isCurrent
                          ? AppColors.infoBlue
                          : AppColors.border,
                  width: 1.8,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: AppColors.successGreen)
                    : isCurrent
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.infoBlue,
                            ),
                          )
                        : Text(
                            '${index + 1}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 22,
                color: isDone ? AppColors.successGreen : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 14,
                    color: isDone || isCurrent ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  isDone
                      ? 'Confirmed'
                      : isCurrent
                          ? 'In progress…'
                          : 'Waiting',
                  style: AppTextStyles.caption.copyWith(
                    color: isDone
                        ? AppColors.successGreen
                        : isCurrent
                            ? AppColors.infoBlue
                            : AppColors.textMuted,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class MessageBubble extends StatelessWidget {
  final EmergencyMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.from == 'me';
    final timeStr = _formatTime(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.emergencyRedBg : AppColors.successGreenBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe
                  ? AppColors.emergencyRed.withValues(alpha: 0.4)
                  : AppColors.successGreen.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'YOU' : 'RESCUE UNIT',
                style: AppTextStyles.labelCaps.copyWith(
                  fontSize: 10,
                  color: isMe ? AppColors.emergencyRedBright : AppColors.successGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.text,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textMuted),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    _statusLabel(message.status, message.attempts),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLabel(MessageStatus status, int attempts) {
    final (text, color, icon) = switch (status) {
      MessageStatus.delivered => ('Delivered to rescuer', AppColors.successGreen, Icons.done_all),
      MessageStatus.relaying => ('Relaying via mesh', AppColors.infoBlue, Icons.sync),
      MessageStatus.failed => ('Retry needed', AppColors.warningAmber, Icons.error_outline),
      MessageStatus.queued => (
        attempts > 0 ? 'Queued · retry #$attempts' : 'Queued (offline)',
        AppColors.warningAmber,
        Icons.schedule,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

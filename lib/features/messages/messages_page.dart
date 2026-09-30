import 'package:flutter/material.dart';
import '../../core/services/emergency_service.dart';
import '../../core/services/message_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/quick_reply_strip.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_strip.dart';

class MessagesPage extends StatefulWidget {
  final MessageService messageService;
  final EmergencyService? service;
  final bool isStandalone;

  const MessagesPage({
    super.key,
    required this.messageService,
    this.service,
    this.isStandalone = false,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _isComposing = _textController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (presetText == null) {
      _textController.clear();
    }

    await widget.messageService.sendMessage(text, from: 'me');
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Emergency Messages',
              subtitle: 'Short text only · relayed offline',
              onBack: widget.isStandalone ? () => Navigator.pop(context) : null,
              actions: [
                IconButton(
                  tooltip: 'Retry pending messages',
                  onPressed: () async {
                    await widget.messageService.retryNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Retrying message transmission…'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: AppColors.infoBlue),
                ),
              ],
            ),

            // Top Status Strip
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: StatusStrip(),
            ),

            // Stream of Messages
            Expanded(
              child: StreamBuilder<List<EmergencyMessage>>(
                stream: widget.messageService.stream,
                initialData: widget.messageService.messages,
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  final queuedCount = messages.where((m) => m.from == 'me' && m.status == MessageStatus.queued).length;

                  return Column(
                    children: [
                      // Queued Warning Banner
                      if (queuedCount > 0)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.warningAmberBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, color: AppColors.warningAmber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$queuedCount message${queuedCount == 1 ? '' : 's'} queued — auto-resends when a node is in range.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => widget.messageService.retryNow(),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'RETRY',
                                    style: AppTextStyles.labelCaps.copyWith(
                                      color: AppColors.warningAmber,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Expanded(
                        child: messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceElevated,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary, size: 26),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'No Messages Yet',
                                        style: AppTextStyles.displaySmall.copyWith(fontSize: 17),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Use quick responses below — short messages travel reliably across low-bandwidth off-grid mesh.',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  return MessageBubble(message: messages[index]);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Quick Reply Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: QuickReplyStrip(
                replies: MessageService.quickReplies,
                onSelected: (reply) => _handleSend(reply),
              ),
            ),

            // Message Composer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: 120,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type emergency message…',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixText: '${_textController.text.length}/120',
                        suffixStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isComposing ? () => _handleSend() : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _isComposing ? AppColors.emergencyRed : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isComposing ? AppColors.emergencyRed : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: _isComposing ? Colors.white : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

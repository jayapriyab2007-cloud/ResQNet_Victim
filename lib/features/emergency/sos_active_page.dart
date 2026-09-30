import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/emergency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';
import '../../widgets/communication_path_card.dart';
import '../../widgets/emergency_timeline.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_strip.dart';
import '../messages/messages_page.dart';
import 'sos_confirm_page.dart';

class SosActivePage extends StatefulWidget {
  final EmergencyService service;
  final UserProfile profile;
  final Emergency? initialEmergency;
  final bool justCreated;

  const SosActivePage({
    super.key,
    required this.service,
    required this.profile,
    this.initialEmergency,
    this.justCreated = false,
  });

  @override
  State<SosActivePage> createState() => _SosActivePageState();
}

class _SosActivePageState extends State<SosActivePage> {
  Emergency? _emergency;
  StreamSubscription<List<Emergency>>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _emergency = widget.initialEmergency ?? widget.service.currentActive;

    _sub = widget.service.activeListStream.listen((list) {
      if (!mounted) return;
      final match = list.where((e) => e.emergencyId == _emergency?.emergencyId).firstOrNull;
      if (match != null) {
        setState(() {
          _emergency = match;
        });
      }
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _openEmergencyDetails() async {
    if (_emergency == null) return;
    final updated = await Navigator.push<Emergency>(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyDetailsPage(
          service: widget.service,
          profile: widget.profile,
          existingEmergency: _emergency,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _emergency = updated);
    }
  }

  Future<void> _updateLocation() async {
    final loc = await widget.service.location.getPositionWithFallback();
    if (loc != null && _emergency != null) {
      final updated = await widget.service.updateLocationForActive(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        emergencyId: _emergency!.emergencyId,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _emergency = updated);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated coordinates broadcasted: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)} (±${loc.accuracy.round()}m)',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acquiring fresh satellite fix… Please stay in open sky.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Cancel Emergency Alert?',
          style: AppTextStyles.displaySmall.copyWith(fontSize: 19),
        ),
        content: Text(
          'Rescuers will be informed that this emergency alert has been withdrawn.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Alert', style: AppTextStyles.title.copyWith(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (_emergency != null) {
        await widget.service.cancelEmergency(_emergency!.emergencyId);
      } else {
        await widget.service.cancelActiveEmergency();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert cancelled.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergency = _emergency;

    if (emergency == null || emergency.status == 'CANCELLED' || emergency.status == 'CLOSED') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Emergency Tracking',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Active Emergency',
                          style: AppTextStyles.displaySmall.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no active emergency alert broadcast at this moment.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () async {
                            final newEmergency = await widget.service.createMainSos(
                              profile: widget.profile,
                            );
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SosActivePage(
                                  service: widget.service,
                                  profile: widget.profile,
                                  initialEmergency: newEmergency,
                                  justCreated: true,
                                ),
                              ),
                            );
                          },
                          child: const Text('SEND SOS ALERT NOW'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stage = emergency.stage.clamp(0, 6);
    final isMainSos = emergency.source == EmergencySource.mainSos;
    final cardTitle = isMainSos ? 'HELP REQUEST SENT' : 'EMERGENCY SOS SENT';
    final cardSubtitle = isMainSos
        ? 'Your emergency alert has been sent to rescuers.'
        : 'Specific emergency alert (${EmergencyType.label(emergency.type)}) has been sent to rescuers.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: isMainSos ? 'Main SOS Tracking' : 'Emergency SOS Tracking',
              subtitle: 'Broadcasted ${_timeAgo(emergency.timestamp)}',
              onBack: () => Navigator.pop(context),
              actions: [
                if (widget.service.ble.isSimulated || AppConstants.simulationMode)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SimulationBadge(),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Success / Status Confirmation Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMainSos
                            ? AppColors.emergencyRed.withValues(alpha: 0.8)
                            : AppColors.infoBlue.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMainSos ? AppColors.emergencyRed : AppColors.infoBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cardTitle,
                              style: AppTextStyles.labelCaps.copyWith(
                                color: isMainSos ? AppColors.emergencyRedBright : AppColors.infoBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            PriorityBadge(
                              level: emergency.priority,
                              label: emergency.priority == 1
                                  ? 'CRITICAL'
                                  : emergency.priority == 2
                                      ? 'SERIOUS'
                                      : 'URGENT',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cardSubtitle,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),
                        _infoLine('Emergency ID:', emergency.emergencyId, isEmphasized: true),
                        _infoLine(
                          'Source:',
                          isMainSos ? 'MAIN SOS' : 'EMERGENCY SOS',
                          isEmphasized: true,
                        ),
                        _infoLine(
                          'Victim ID:',
                          emergency.victimId.isNotEmpty ? emergency.victimId : 'USR-${widget.profile.deviceId}',
                        ),
                        _infoLine('Emergency Type:', EmergencyType.label(emergency.type)),
                        _infoLine(
                          'Priority:',
                          'P${emergency.priority} · ${emergency.severity}',
                        ),
                        _infoLine('Severity:', emergency.severity),
                        _infoLine(
                          'Location:',
                          emergency.latitude != null
                              ? '${emergency.latitude!.toStringAsFixed(5)}, ${emergency.longitude!.toStringAsFixed(5)} (±${emergency.gpsAccuracy?.round() ?? 10}m)'
                              : 'GPS location captured',
                        ),
                        _infoLine(
                          'Communication:',
                          '${emergency.deliveryState} (${CommunicationState.userFriendlyLabel(emergency.communicationState)})',
                        ),
                        if (emergency.battery > 0)
                          _infoLine('Battery:', '${emergency.battery}%'),
                        if (emergency.repeatedCount > 1)
                          _infoLine('Repeated SOS:', '${emergency.repeatedCount} (deduplicated)'),
                        if (emergency.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '“${emergency.note}”',
                              style: AppTextStyles.caption.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Action Buttons
                  if (isMainSos) ...[
                    // MAIN SOS Action 1: Add Emergency Details
                    FilledButton.icon(
                      onPressed: _openEmergencyDetails,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.warningAmber, width: 1.2),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.playlist_add, size: 20, color: AppColors.warningAmber),
                      label: Text(
                        emergency.type == EmergencyType.other ? 'ADD EMERGENCY DETAILS' : 'UPDATE EMERGENCY DETAILS',
                        style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Action: SEND MESSAGE
                  FilledButton.icon(
                    onPressed: () {
                      if (widget.service.messageService != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessagesPage(
                              messageService: widget.service.messageService!,
                              service: widget.service,
                              isStandalone: true,
                            ),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.infoBlue),
                    label: Text(
                      'SEND MESSAGE',
                      style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action: UPDATE LOCATION
                  FilledButton.icon(
                    onPressed: _updateLocation,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.my_location, size: 18, color: AppColors.infoBlue),
                    label: Text(
                      'UPDATE LOCATION',
                      style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action: CANCEL SOS
                  OutlinedButton.icon(
                    onPressed: _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.emergencyRed, width: 1.2),
                      foregroundColor: AppColors.emergencyRedBright,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      'CANCEL SOS',
                      style: AppTextStyles.title.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emergencyRedBright,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Compact Status Strip
                  StatusStrip(
                    gpsActive: emergency.latitude != null,
                    meshActive: true,
                    nodeCount: 3,
                    batteryLevel: emergency.battery > 0 ? emergency.battery : 64,
                  ),

                  const SizedBox(height: 14),

                  if (stage < 2)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmberBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_tethering_error_rounded, color: AppColors.warningAmber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No direct tower connection. Your SOS packet is stored locally and hopping through nearby ResQNet mesh nodes.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. Delivery Timeline
                  EmergencyTimeline(stage: stage),

                  const SizedBox(height: 14),

                  // 5. Visual Communication Path
                  CommunicationPathCard(currentStage: stage),

                  const SizedBox(height: 14),

                  // 6. Responder Dispatch Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESPONDER DISPATCH STATUS',
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              emergency.status,
                              style: AppTextStyles.title.copyWith(
                                color: emergency.status == 'TEAM ASSIGNED'
                                    ? AppColors.successGreen
                                    : AppColors.infoBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              emergency.contactNotified,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stage >= 5
                              ? 'Rescue unit is deployed. Maintain your position if safe and keep your phone awake.'
                              : 'Packet is in flight across the mesh network. Stay calm and preserve battery.',
                          style: AppTextStyles.caption.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value, {bool isEmphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isEmphasized
                  ? AppTextStyles.title.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.infoBlue)
                  : AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

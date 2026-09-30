import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/emergency_service.dart';
import '../../core/services/priority_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';
import 'sos_active_page.dart';

typedef SosConfirmPage = EmergencyDetailsPage;

class EmergencyDetailsPage extends StatefulWidget {
  final EmergencyService service;
  final UserProfile profile;
  final Emergency? existingEmergency;
  final String? initialType;

  const EmergencyDetailsPage({
    super.key,
    required this.service,
    required this.profile,
    this.existingEmergency,
    this.initialType,
  });

  @override
  State<EmergencyDetailsPage> createState() => _EmergencyDetailsPageState();
}

class _EmergencyDetailsPageState extends State<EmergencyDetailsPage> {
  late String _selectedType;
  late String _selectedSeverity;
  late int _peopleAffected;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _gpsStatusText;
  double? _currentLat;
  double? _currentLng;
  double? _gpsAccuracy;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEmergency;

    if (existing != null) {
      _selectedType = existing.type;
    } else {
      _selectedType = widget.initialType ?? EmergencyType.other;
    }

    _selectedSeverity = existing?.severity ?? Severity.critical;
    _peopleAffected = existing?.peopleAffected ?? 1;
    _noteController = TextEditingController(text: existing?.note ?? '');

    _fetchGpsPreview();
  }

  Future<void> _fetchGpsPreview() async {
    final loc = await widget.service.location.getPositionWithFallback();
    if (!mounted) return;
    setState(() {
      if (loc != null) {
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;
        _gpsAccuracy = loc.accuracy;
        _gpsStatusText = loc.isLive ? 'Live Satellite Fix' : 'Using Last Known Position';
      } else {
        _gpsStatusText = 'Location Unavailable';
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveDetails() async {
    setState(() => _isSaving = true);

    try {
      final target = widget.existingEmergency ?? widget.service.currentActive;
      if (target != null) {
        // UPDATE existing active emergency (same emergency_id)
        final updated = await widget.service.updateEmergencyDetails(
          emergencyId: target.emergencyId,
          type: _selectedType,
          severity: _selectedSeverity,
          peopleAffected: _peopleAffected,
          note: _noteController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency updated to ${EmergencyType.label(_selectedType)}. Transmitted to rescue units.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context, updated);
      } else {
        // Standalone creation fallback
        final Emergency emergency = await widget.service.createAndSend(
          profile: widget.profile,
          type: _selectedType,
          severity: _selectedSeverity,
          peopleAffected: _peopleAffected,
          note: _noteController.text.trim(),
          battery: 64,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SosActivePage(
              service: widget.service,
              profile: widget.profile,
              initialEmergency: emergency,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details saved locally. ResQNet will synchronize with the network.'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.existingEmergency != null;
    final priority = PriorityService.calculate(
      type: _selectedType,
      severity: _selectedSeverity,
      peopleAffected: _peopleAffected,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: isUpdate ? 'Emergency Details' : 'Specify Emergency',
              subtitle: isUpdate
                  ? 'Updating SOS ID: ${widget.existingEmergency!.emergencyId}'
                  : 'Add incident information for responders',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUpdate ? AppColors.infoBlueBg : AppColors.warningAmberBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUpdate
                            ? AppColors.infoBlue.withValues(alpha: 0.4)
                            : AppColors.warningAmber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isUpdate ? Icons.info_outline : Icons.warning_amber_rounded,
                          color: isUpdate ? AppColors.infoBlue : AppColors.warningAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isUpdate
                                ? 'Your alert has already been transmitted to rescuers as P1 Critical. Adding details here helps rescue teams deploy the appropriate equipment and vehicles.'
                                : 'Select the nature of the emergency to assist the rescue command center in resource allocation.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 1. Emergency Type Selection
                  Text(
                    'WHAT IS HAPPENING?',
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the situation type that best describes the emergency',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: EmergencyType.all.length,
                    itemBuilder: (context, index) {
                      final type = EmergencyType.all[index];
                      final isSelected = _selectedType == type;

                      return InkWell(
                        onTap: () => setState(() => _selectedType = type),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.emergencyRedBg : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.emergencyRed : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(EmergencyType.emoji(type), style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 6),
                              Text(
                                EmergencyType.label(type),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 2. Severity Selection
                  Text(
                    '2. SITUATION SEVERITY',
                    style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _severityButton(Severity.critical, 'Critical', 'Life Threat'),
                      const SizedBox(width: 8),
                      _severityButton(Severity.serious, 'Serious', 'High Hazard'),
                      const SizedBox(width: 8),
                      _severityButton(Severity.urgent, 'Urgent', 'Assistance'),
                      const SizedBox(width: 8),
                      _severityButton(Severity.general, 'General', 'Support'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. People Affected
                  Text(
                    '3. PEOPLE AFFECTED',
                    style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 2, 3, 4, 5].map((count) {
                      final label = count == 5 ? '5+' : '$count';
                      final isSelected = _peopleAffected == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => setState(() => _peopleAffected = count),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.emergencyRed : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.emergencyRed : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: AppTextStyles.title.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 4. Situation Details (Optional)
                  Text(
                    '4. SITUATION DETAILS (OPTIONAL)',
                    style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLength: 140,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Trapped on roof, water level rising rapidly…',
                      counterStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Summary Preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUpdate ? 'UPDATED INCIDENT PROFILE' : 'EMERGENCY SUMMARY',
                              style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                            ),
                            PriorityBadge(level: priority.level, label: priority.label),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _summaryRow('Emergency Type', EmergencyType.label(_selectedType)),
                        _summaryRow('Severity', Severity.label(_selectedSeverity)),
                        _summaryRow('People Affected', _peopleAffected == 5 ? '5+ people' : '$_peopleAffected people'),
                        _summaryRow(
                          'Location',
                          _currentLat != null
                              ? '${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)} (±${_gpsAccuracy?.round() ?? 10}m)'
                              : (_gpsStatusText ?? 'Acquiring GPS fix…'),
                        ),
                        if (isUpdate)
                          _summaryRow('Emergency ID', widget.existingEmergency!.emergencyId),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save / Update Action Button
                  FilledButton(
                    onPressed: _isSaving ? null : _handleSaveDetails,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isUpdate ? Icons.check_circle_outline : Icons.emergency_share, size: 22, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                isUpdate ? 'UPDATE EMERGENCY DETAILS' : 'BROADCAST SOS ALERT',
                                style: AppTextStyles.title.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _severityButton(String key, String title, String subtitle) {
    final isSelected = _selectedSeverity == key;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSeverity = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.emergencyRedBg : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.emergencyRed : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: AppTextStyles.title.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppColors.emergencyRedBright : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.title.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

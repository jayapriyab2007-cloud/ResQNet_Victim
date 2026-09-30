import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/emergency.dart';
import '../../widgets/communication_path_card.dart';
import '../../widgets/emergency_timeline.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';

class HistoryPage extends StatefulWidget {
  final LocalStore store;
  final bool isStandalone;

  const HistoryPage({
    super.key,
    required this.store,
    this.isStandalone = false,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Emergency> _emergencies = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // 'ALL', 'MAIN_SOS', 'EMERGENCY_SOS'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.store.loadEmergencies();
    if (!mounted) return;
    setState(() {
      _emergencies = list;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _formatHumanDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == dt.year && yesterday.month == dt.month && yesterday.day == dt.day;

    final clock = _formatClock(dt);
    if (isToday) return 'Today, $clock';
    if (isYesterday) return 'Yesterday, $clock';
    return '${_formatDate(dt)}, $clock';
  }

  List<Emergency> get _filteredEmergencies {
    if (_selectedFilter == 'ALL') return _emergencies;
    return _emergencies.where((e) => e.source == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmergencies;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Incident History',
              subtitle: 'Every SOS this device has broadcasted',
              onBack: widget.isStandalone ? () => Navigator.pop(context) : null,
              actions: [
                IconButton(
                  tooltip: 'Refresh History',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: AppColors.infoBlue),
                ),
              ],
            ),

            // Top Filter Chips (ALL, MAIN SOS, EMERGENCY SOS)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterButton('ALL', 'ALL', count: _emergencies.length),
                  const SizedBox(width: 8),
                  _filterButton(
                    'MAIN SOS',
                    EmergencySource.mainSos,
                    count: _emergencies.where((e) => e.source == EmergencySource.mainSos).length,
                  ),
                  const SizedBox(width: 8),
                  _filterButton(
                    'EMERGENCY SOS',
                    EmergencySource.emergencySos,
                    count: _emergencies.where((e) => e.source == EmergencySource.emergencySos).length,
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.emergencyRed,
                      backgroundColor: AppColors.surface,
                      child: filtered.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
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
                                          child: const Icon(Icons.history_toggle_off, size: 32, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _selectedFilter == 'ALL'
                                              ? 'No Incidents Recorded'
                                              : 'No ${_selectedFilter == EmergencySource.mainSos ? 'Main SOS' : 'Emergency SOS'} Records',
                                          style: AppTextStyles.displaySmall.copyWith(fontSize: 18),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'When you broadcast an emergency SOS, its timeline, source, and delivery state will be recorded here.',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.bodySecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                final isActive = e.status != 'CANCELLED' && e.status != 'CLOSED';
                                final isMainSos = e.source == EmergencySource.mainSos;
                                final sourceBadgeLabel = isMainSos ? 'MAIN SOS' : 'EMERGENCY SOS';
                                final sourceBadgeEmoji = isMainSos ? '🚨' : EmergencyType.emoji(e.type);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: AppColors.surface,
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isActive
                                          ? AppColors.emergencyRed.withValues(alpha: 0.6)
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isActive ? AppColors.emergencyRedBg : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          sourceBadgeEmoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              e.emergencyId,
                                              style: AppTextStyles.labelCaps.copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.infoBlue,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _sourceBadge(sourceBadgeLabel, isMain: isMainSos),
                                            const Spacer(),
                                            _outcomeBadge(e.status),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                EmergencyType.label(e.type),
                                                style: AppTextStyles.title.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            PriorityBadge(
                                              level: e.priority,
                                              label: e.severity,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatHumanDate(e.timestamp),
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                      ),
                                    ),
                                    children: [
                                      const Divider(color: AppColors.border, height: 16),
                                      _detailRow('Emergency ID', e.emergencyId),
                                      _detailRow('Source', isMainSos ? 'MAIN SOS' : 'EMERGENCY SOS'),
                                      _detailRow('Victim ID', e.victimId.isNotEmpty ? e.victimId : 'Unavailable'),
                                      _detailRow('Emergency Type', EmergencyType.label(e.type)),
                                      _detailRow('Severity', e.severity),
                                      _detailRow('Priority', 'P${e.priority}'),
                                      _detailRow('Date / Time', '${_formatDate(e.timestamp)} at ${_formatClock(e.timestamp)}'),
                                      _detailRow('Status', e.status),
                                      _detailRow('Communication State', CommunicationState.userFriendlyLabel(e.communicationState)),
                                      _detailRow('Delivery State', e.deliveryState),
                                      if (e.latitude != null)
                                        _detailRow(
                                          'Current GPS',
                                          '${e.latitude!.toStringAsFixed(5)}, ${e.longitude!.toStringAsFixed(5)}',
                                        ),
                                      if (e.gpsAccuracy != null)
                                        _detailRow('GPS Accuracy', '±${e.gpsAccuracy!.round()} meters'),
                                      if (e.battery > 0)
                                        _detailRow('Device Battery', '${e.battery}%'),
                                      _detailRow('People Affected', '${e.peopleAffected}'),
                                      if (e.repeatedCount > 1)
                                        _detailRow('Repeated SOS Count', '${e.repeatedCount} (deduplicated)'),
                                      if (e.contactNotified.isNotEmpty)
                                        _detailRow('Contact Alerted', e.contactNotified),
                                      if (e.note.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '“${e.note}”',
                                            style: AppTextStyles.caption.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      // Timeline & Path visual
                                      EmergencyTimeline(stage: e.stage.clamp(0, 6)),
                                      const SizedBox(height: 8),
                                      CommunicationPathCard(currentStage: e.stage.clamp(0, 6)),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, String value, {int count = 0}) {
    final isSelected = _selectedFilter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.emergencyRed : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            count > 0 ? '$label ($count)' : label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelCaps.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.emergencyRedBright : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceBadge(String label, {required bool isMain}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMain ? AppColors.emergencyRedBg : AppColors.infoBlueBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isMain ? AppColors.emergencyRed : AppColors.infoBlue).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelCaps.copyWith(
          color: isMain ? AppColors.emergencyRedBright : AppColors.infoBlue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _outcomeBadge(String status) {
    final (label, color, bg) = switch (status.toUpperCase()) {
      'CANCELLED' => ('CANCELLED', AppColors.textMuted, AppColors.surfaceElevated),
      'REQUESTED' || 'SOS SENT' => ('ACTIVE', AppColors.emergencyRedBright, AppColors.emergencyRedBg),
      'CLOSED' || 'RESCUED' => ('RESCUED', AppColors.successGreen, AppColors.successGreenBg),
      _ => ('DELIVERED', AppColors.infoBlue, AppColors.infoBlueBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelCaps.copyWith(color: color, fontSize: 9.5),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
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
              style: AppTextStyles.title.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

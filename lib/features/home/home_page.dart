import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/emergency_service.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';
import '../../widgets/sos_orb.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_strip.dart';
import '../contacts/contacts_page.dart';
import '../emergency/sos_active_page.dart';
import '../history/history_page.dart';
import '../location/location_page.dart';
import '../medical/medical_page.dart';
import '../messages/messages_page.dart';
import '../network/network_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  final LocalStore store;
  final EmergencyService emergencyService;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.store,
    required this.emergencyService,
    required this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;
  UserProfile _profile = UserProfile();
  List<Emergency> _activeEmergencies = [];
  StreamSubscription<List<Emergency>>? _activeListSub;
  bool _hasInternet = false;
  Timer? _ticker;
  bool _isTriggeringMainSos = false;
  String? _triggeringEmergencyType;

  @override
  void initState() {
    super.initState();
    _load();

    _activeEmergencies = widget.emergencyService.activeEmergencies;
    _activeListSub = widget.emergencyService.activeListStream.listen((list) {
      if (!mounted) return;
      setState(() => _activeEmergencies = list);
    });

    _ticker = Timer.periodic(const Duration(seconds: 4), (_) async {
      final net = await widget.emergencyService.connectivity.hasInternet();
      if (mounted && net != _hasInternet) {
        setState(() => _hasInternet = net);
      }
    });
  }

  @override
  void dispose() {
    _activeListSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await widget.store.loadProfile();
    final net = await widget.emergencyService.connectivity.hasInternet();
    if (!mounted) return;
    setState(() {
      _profile = p ?? UserProfile();
      _hasInternet = net;
      _activeEmergencies = widget.emergencyService.activeEmergencies;
    });
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return 'None yet';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _triggerMainSos() async {
    if (_isTriggeringMainSos) return;
    setState(() => _isTriggeringMainSos = true);
    try {
      final emergency = await widget.emergencyService.createMainSos(
        profile: _profile,
        battery: 64,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SosActivePage(
            service: widget.emergencyService,
            profile: _profile,
            initialEmergency: emergency,
            justCreated: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTriggeringMainSos = false);
      }
    }
  }

  Future<void> _triggerEmergencySos(String type) async {
    if (_triggeringEmergencyType != null) return;
    setState(() => _triggeringEmergencyType = type);
    try {
      final emergency = await widget.emergencyService.createEmergencySos(
        profile: _profile,
        type: type,
        battery: 64,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SosActivePage(
            service: widget.emergencyService,
            profile: _profile,
            initialEmergency: emergency,
            justCreated: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _triggeringEmergencyType = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgService = widget.emergencyService.messageService;

    final tabs = [
      _buildHomeDashboard(),
      if (msgService != null)
        MessagesPage(
          messageService: msgService,
          service: widget.emergencyService,
        )
      else
        const Center(child: Text('Message service initializing…')),
      LocationPage(
        locationService: widget.emergencyService.location,
        emergencyService: widget.emergencyService,
      ),
      NetworkPage(
        bleService: widget.emergencyService.ble,
        emergencyService: widget.emergencyService,
      ),
      ProfilePage(
        store: widget.store,
        profile: _profile,
        onSaved: _load,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.surfaceElevated,
          selectedIndex: _currentTab,
          onDestinationSelected: (i) => setState(() => _currentTab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.emergencyRed),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: AppColors.emergencyRed),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on, color: AppColors.emergencyRed),
              label: 'Location',
            ),
            NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar, color: AppColors.emergencyRed),
              label: 'Network',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.emergencyRed),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeDashboard() {
    final hasMainSosActive = _activeEmergencies.any(
      (e) => e.source == EmergencySource.mainSos && e.status != 'CANCELLED' && e.status != 'CLOSED',
    );

    final connectionStatus = _hasInternet
        ? 'ONLINE'
        : (widget.emergencyService.ble.isSimulated || AppConstants.simulationMode)
            ? 'SIMULATION MODE'
            : widget.emergencyService.ble.connected
                ? 'MESH CONNECTED'
                : 'OFFLINE';

    final lastMsg = widget.emergencyService.messageService?.messages.isNotEmpty == true
        ? widget.emergencyService.messageService!.messages.last
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.emergencyRed,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. TOP BAR / STATUS
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESQNET',
                      style: AppTextStyles.displaySmall.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Emergency Assistance Network',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ConnectionIndicator(status: connectionStatus),
            ],
          ),

          const SizedBox(height: 20),

          // 2. MAIN SOS BUTTON (Immediate Generic Alert)
          Column(
            children: [
              Text(
                'MAIN SOS',
                style: AppTextStyles.labelCaps.copyWith(
                  color: hasMainSosActive ? AppColors.emergencyRedBright : AppColors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasMainSosActive ? 'MAIN SOS ACTIVE — RELAYING' : 'IMMEDIATE EMERGENCY BROADCAST',
                style: AppTextStyles.title.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: hasMainSosActive ? AppColors.emergencyRedBright : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              SosOrb(
                isSosActive: hasMainSosActive,
                onTap: _triggerMainSos,
              ),
              const SizedBox(height: 12),
              Text(
                'Send immediate emergency alert',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. EMERGENCY SOS CARD (Specific Disaster / Emergency Alert)
          _buildEmergencySosCard(),

          const SizedBox(height: 22),

          // 4. ACTIVE EMERGENCIES (Separately display Active Main SOS & Active Emergency SOS)
          if (_activeEmergencies.isNotEmpty) ...[
            _buildActiveEmergenciesSection(),
            const SizedBox(height: 22),
          ],

          // 5. NETWORK / GPS / BATTERY STATUS
          const StatusStrip(
            gpsActive: true,
            meshActive: true,
            nodeCount: 3,
            batteryLevel: 64,
          ),

          const SizedBox(height: 16),

          // Device & Link Status Section
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
                  'DEVICE & LINK STATUS',
                  style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                _statusRow(
                  icon: Icons.satellite_alt_rounded,
                  label: 'Satellite Location',
                  value: 'GPS Available (±12m)',
                  valueColor: AppColors.successGreen,
                ),
                const Divider(color: AppColors.border, height: 18),
                _statusRow(
                  icon: Icons.hub_rounded,
                  label: 'Off-Grid Mesh',
                  value: '3 Nodes In Range',
                  valueColor: AppColors.successGreen,
                ),
                const Divider(color: AppColors.border, height: 18),
                _statusRow(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Device Battery',
                  value: '64%',
                  valueColor: AppColors.successGreen,
                ),
                const Divider(color: AppColors.border, height: 18),
                _statusRow(
                  icon: Icons.send_rounded,
                  label: 'Last Transmission',
                  value: _formatTimeAgo(lastMsg?.timestamp),
                  valueColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 6. OTHER HOME CONTENT (Action Cards Grid)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _actionCard(
                icon: Icons.chat_bubble_outline,
                title: 'Send Message',
                subtitle: 'Low-bandwidth text',
                onTap: () => setState(() => _currentTab = 1),
              ),
              _actionCard(
                icon: Icons.location_on_outlined,
                title: 'Share Location',
                subtitle: 'GPS coordinates',
                onTap: () => setState(() => _currentTab = 2),
              ),
              _actionCard(
                icon: Icons.medical_services_outlined,
                title: 'Medical Info',
                subtitle: 'Blood & conditions',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicalPage(
                        store: widget.store,
                        profile: _profile,
                        onSaved: _load,
                      ),
                    ),
                  );
                },
              ),
              _actionCard(
                icon: Icons.radar_outlined,
                title: 'Network Status',
                subtitle: 'Off-grid mesh nodes',
                onTap: () => setState(() => _currentTab = 3),
              ),
              _actionCard(
                icon: Icons.contact_emergency_outlined,
                title: 'Contacts',
                subtitle: 'Gateway alerts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactsPage(store: widget.store),
                    ),
                  );
                },
              ),
              _actionCard(
                icon: Icons.history_rounded,
                title: 'Incident History',
                subtitle: 'Past SOS logs',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryPage(store: widget.store, isStandalone: true),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Cellular unavailable. ResQNet continuously keeps transmitting distress packets through nearby off-grid devices.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 4. Prominent EMERGENCY SOS CARD with at least 10 Emergency Types
  Widget _buildEmergencySosCard() {
    final emergencyItems = [
      (EmergencyType.flood, 'FLOOD', Icons.water, const Color(0xFF29B6F6)),
      (EmergencyType.cyclone, 'CYCLONE', Icons.air, const Color(0xFF26A69A)),
      (EmergencyType.fire, 'FIRE', Icons.local_fire_department, const Color(0xFFFF5722)),
      (EmergencyType.forestFire, 'FOREST FIRE', Icons.forest, const Color(0xFF4CAF50)),
      (EmergencyType.earthquake, 'EARTHQUAKE', Icons.public, const Color(0xFFAB47BC)),
      (EmergencyType.medical, 'MEDICAL', Icons.medical_services, const Color(0xFFE53935)),
      (EmergencyType.accident, 'ROAD ACCIDENT', Icons.car_crash, const Color(0xFFFFA726)),
      (EmergencyType.missingPerson, 'MISSING PERSON', Icons.person_search, const Color(0xFF42A5F5)),
      (EmergencyType.safety, 'SAFETY / CRIME', Icons.security, const Color(0xFFFFD54F)),
      (EmergencyType.other, 'OTHER', Icons.warning_amber, const Color(0xFFB0BEC5)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.emergencyRed.withValues(alpha: 0.6),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🚨', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEND EMERGENCY SOS',
                      style: AppTextStyles.displaySmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emergencyRedBright,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select the type of emergency and send specific information to rescuers.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Grid of 10 Emergency Types with large touch targets
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emergencyItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.3,
            ),
            itemBuilder: (context, index) {
              final item = emergencyItems[index];
              final typeKey = item.$1;
              final label = item.$2;
              final icon = item.$3;
              final color = item.$4;

              final isTriggering = _triggeringEmergencyType == typeKey;
              final isCurrentlyActive = _activeEmergencies.any(
                (e) =>
                    e.source == EmergencySource.emergencySos &&
                    e.type.toUpperCase() == typeKey.toUpperCase() &&
                    e.status != 'CANCELLED' &&
                    e.status != 'CLOSED',
              );

              return Material(
                color: isCurrentlyActive ? AppColors.emergencyRedBg : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: isTriggering ? null : () => _triggerEmergencySos(typeKey),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentlyActive
                            ? AppColors.emergencyRed
                            : isTriggering
                                ? AppColors.warningAmber
                                : AppColors.border,
                        width: isCurrentlyActive ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: AppTextStyles.labelCaps.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrentlyActive
                                      ? AppColors.emergencyRedBright
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isCurrentlyActive)
                                Text(
                                  'ACTIVE',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 9,
                                    color: AppColors.emergencyRedBright,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isTriggering)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 4. Active Emergencies section displaying Main SOS and Emergency SOS separately
  Widget _buildActiveEmergenciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emergencyRed,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ACTIVE EMERGENCIES (${_activeEmergencies.length})',
              style: AppTextStyles.labelCaps.copyWith(
                color: AppColors.emergencyRedBright,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final em in _activeEmergencies)
          _buildActiveEmergencyCard(em),
      ],
    );
  }

  Widget _buildActiveEmergencyCard(Emergency em) {
    final isMain = em.source == EmergencySource.mainSos;
    final sourceTitle = isMain ? 'ACTIVE MAIN SOS' : 'ACTIVE EMERGENCY SOS';
    final sourceBadgeEmoji = isMain ? '🚨' : EmergencyType.emoji(em.type);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SosActivePage(
              service: widget.emergencyService,
              profile: _profile,
              initialEmergency: em,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMain
                ? AppColors.emergencyRed.withValues(alpha: 0.8)
                : AppColors.infoBlue.withValues(alpha: 0.8),
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$sourceBadgeEmoji $sourceTitle',
                  style: AppTextStyles.labelCaps.copyWith(
                    color: isMain ? AppColors.emergencyRedBright : AppColors.infoBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                const Spacer(),
                PriorityBadge(
                  level: em.priority,
                  label: em.severity,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${em.emergencyId} · ${EmergencyType.label(em.type)}',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'TRACK >',
                  style: AppTextStyles.labelCaps.copyWith(
                    color: isMain ? AppColors.emergencyRedBright : AppColors.infoBlue,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: AppColors.border, height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${em.status}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  em.latitude != null
                      ? 'Location: Received'
                      : 'Location: Pending fix',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'State: ${CommunicationState.userFriendlyLabel(em.communicationState)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  _formatTimeAgo(em.timestamp),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            if (em.repeatedCount > 1) ...[
              const SizedBox(height: 4),
              Text(
                'Repeated alerts sent: x${em.repeatedCount}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warningAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.infoBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.title.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.title.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    );
  }
}

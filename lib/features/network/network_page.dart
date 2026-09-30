import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ble_service.dart';
import '../../core/services/emergency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';
import '../handheld/handheld_page.dart';

class NetworkPage extends StatefulWidget {
  final BleService bleService;
  final EmergencyService? emergencyService;
  final bool isStandalone;

  const NetworkPage({
    super.key,
    required this.bleService,
    this.emergencyService,
    this.isStandalone = false,
  });

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  int _nodeCount = 3;
  int _battery = 64;
  bool _isScanning = false;

  static const List<Map<String, dynamic>> _mockNodes = [
    {'name': 'Relay Node Alpha (SX1262)', 'bars': 4, 'distance': '~65m', 'role': 'Relay Hop 1'},
    {'name': 'Relay Node Bravo (ESP32)', 'bars': 3, 'distance': '~140m', 'role': 'Relay Hop 2'},
    {'name': 'Gateway Node Charlie', 'bars': 2, 'distance': '~310m', 'role': 'Perimeter Gateway'},
  ];

  Future<void> _rescan() async {
    setState(() => _isScanning = true);
    await widget.bleService.scanAndConnect();
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _nodeCount = Random().nextInt(3) + 2;
      _battery = max(10, _battery - 1);
      _isScanning = false;
    });

    widget.emergencyService?.messageService?.flushQueue();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Network scan complete. Off-grid mesh active.'),
        backgroundColor: AppColors.surfaceElevated,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queuedCount = widget.emergencyService?.messageService?.messages
            .where((m) => m.from == 'me' && m.status.name == 'queued')
            .length ??
        0;

    final isMeshOnline = _nodeCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Network Status',
              subtitle: 'What your phone can reach right now',
              onBack: widget.isStandalone ? () => Navigator.pop(context) : null,
              actions: [
                if (widget.bleService.isSimulated || AppConstants.simulationMode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SimulationBadge(),
                  ),
              ],
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Big Mesh Status Card
                  _bigStatusCard(
                    icon: Icons.hub_rounded,
                    title: isMeshOnline ? 'ResQNet Mesh Active' : 'Searching for LoRa Mesh…',
                    body: isMeshOnline
                        ? '$_nodeCount nearby relay device${_nodeCount == 1 ? '' : 's'} ready to pass your emergency packets forward.'
                        : 'No nearby nodes found yet. Your device continues scanning automatically.',
                    tone: isMeshOnline ? _Tone.good : _Tone.warn,
                  ),

                  const SizedBox(height: 12),

                  // 2. Big GPS Status Card
                  _bigStatusCard(
                    icon: Icons.satellite_alt_rounded,
                    title: 'Satellite GPS Active',
                    body: 'Position is fixed directly via orbital navigation satellites. Zero cellular required.',
                    tone: _Tone.good,
                  ),

                  const SizedBox(height: 12),

                  // 3. Internet Status Card
                  _bigStatusCard(
                    icon: Icons.wifi_off_rounded,
                    title: 'Cellular / Internet: Offline',
                    body: 'Normal apps, voice calls, and cloud sync are unavailable here. ResQNet operates entirely offline.',
                    tone: _Tone.neutral,
                  ),

                  const SizedBox(height: 12),

                  // 4. Battery Status Card
                  _bigStatusCard(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Battery: $_battery%',
                    body: _battery > 30
                        ? 'Sufficient power to sustain LoRa beaconing and emergency communication for hours.'
                        : 'Low battery level. Dim screen brightness to preserve emergency radio relays.',
                    tone: _battery > 30 ? _Tone.good : _Tone.warn,
                  ),

                  const SizedBox(height: 18),

                  // Nearby Relay Nodes
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NEARBY RELAY NODES',
                              style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                            ),
                            if (widget.bleService.isSimulated || AppConstants.simulationMode)
                              Text(
                                'SIMULATION MODE',
                                style: AppTextStyles.labelCaps.copyWith(
                                  color: AppColors.infoBlue,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._mockNodes.take(_nodeCount).map((node) {
                          final bars = node['bars'] as int;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.router_outlined, size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        node['name'] as String,
                                        style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        '${node['role']} · ${node['distance']}',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                // Signal Bars
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(4, (i) {
                                    final filled = i < bars;
                                    return Container(
                                      width: 4,
                                      height: 6.0 + (i * 3.5),
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      decoration: BoxDecoration(
                                        color: filled ? AppColors.successGreen : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(1.5),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Message Queue Summary Panel
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
                          'MESSAGE QUEUE & TRANSMISSION',
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pending in Queue', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            Text(
                              queuedCount > 0 ? '$queuedCount messages' : '0 (Up to date)',
                              style: AppTextStyles.title.copyWith(
                                fontSize: 13,
                                color: queuedCount > 0 ? AppColors.warningAmber : AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Last Transmission', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            Text(
                              'Active mesh connected',
                              style: AppTextStyles.title.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  FilledButton.icon(
                    onPressed: _isScanning ? null : _rescan,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.radar, color: AppColors.infoBlue),
                    label: Text(
                      _isScanning ? 'SCANNING OFF-GRID NODES…' : 'SCAN / REFRESH MESH',
                      style: AppTextStyles.title.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HandheldPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    icon: const Icon(Icons.bluetooth, color: AppColors.infoBlue),
                    label: const Text('BLE HANDHELD DEVICE SETTINGS'),
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

  Widget _bigStatusCard({
    required IconData icon,
    required String title,
    required String body,
    required _Tone tone,
  }) {
    final (borderColor, bgColor, iconColor) = switch (tone) {
      _Tone.good => (AppColors.successGreen.withValues(alpha: 0.4), AppColors.successGreenBg, AppColors.successGreen),
      _Tone.warn => (AppColors.warningAmber.withValues(alpha: 0.4), AppColors.warningAmberBg, AppColors.warningAmber),
      _Tone.neutral => (AppColors.border, AppColors.surface, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: tone == _Tone.good ? AppColors.textPrimary : iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { good, warn, neutral }

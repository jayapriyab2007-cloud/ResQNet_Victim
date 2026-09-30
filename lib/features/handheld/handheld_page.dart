import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/communication_path_card.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';

class HandheldPage extends StatefulWidget {
  final BleService? bleService;

  const HandheldPage({
    super.key,
    this.bleService,
  });

  @override
  State<HandheldPage> createState() => _HandheldPageState();
}

class _HandheldPageState extends State<HandheldPage> {
  late final BleService _ble;
  late final bool _ownedBle;
  String _state = 'DISCONNECTED';
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.bleService != null) {
      _ble = widget.bleService!;
      _ownedBle = false;
    } else {
      _ble = BleService();
      _ownedBle = true;
    }

    _state = _ble.currentStatus;
    _sub = _ble.state.listen((val) {
      if (!mounted) return;
      setState(() => _state = val);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_ownedBle) {
      _ble.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_ble.connected) {
      await _ble.disconnect();
    } else {
      await _ble.scanAndConnect();
    }
  }

  String _stateLabel() {
    switch (_state) {
      case 'SIMULATION_CONNECTED':
        return 'Connected (Simulation)';
      case 'CONNECTED':
        return 'Physical Handheld Connected';
      case 'CONNECTING':
        return 'Pairing Handheld Bridge…';
      case 'SCANNING':
        return 'Scanning for LoRa Handheld…';
      case 'PACKET_ACK':
        return 'Packet Acknowledged by LoRa';
      case 'PACKET_TRANSMITTED':
        return 'Transmitting to Bridge…';
      case 'PACKET_QUEUED':
        return 'Packet Buffered in Radio Queue';
      default:
        return 'Handheld Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _ble.connected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'BLE LoRa Handheld',
              subtitle: 'Phone-to-radio physical bridge',
              onBack: () => Navigator.pop(context),
              actions: [
                if (_ble.isSimulated || AppConstants.simulationMode)
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
                  // Main Connection Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isConnected
                            ? AppColors.successGreen.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? AppColors.successGreenBg : AppColors.surfaceElevated,
                            border: Border.all(
                              color: isConnected ? AppColors.successGreen : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                            size: 34,
                            color: isConnected ? AppColors.successGreen : AppColors.infoBlue,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _stateLabel(),
                          style: AppTextStyles.displaySmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _ble.isSimulated || AppConstants.simulationMode
                              ? 'SIMULATION MODE — Demonstrates ESP32 + SX1262 LoRa transmission'
                              : 'Physical Bluetooth Low Energy connection',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _state == 'SCANNING' ? null : _toggleScan,
                          style: FilledButton.styleFrom(
                            backgroundColor: isConnected ? AppColors.surfaceElevated : AppColors.emergencyRed,
                            foregroundColor: isConnected ? AppColors.textPrimary : Colors.white,
                            side: isConnected ? const BorderSide(color: AppColors.border) : null,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_searching, size: 20),
                          label: Text(
                            _state == 'SCANNING'
                                ? 'SEARCHING…'
                                : isConnected
                                    ? 'DISCONNECT HANDHELD'
                                    : 'SCAN & CONNECT TO HANDHELD',
                            style: AppTextStyles.title.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Discovered Devices Section
                  if (_ble.discoveredDevices.isNotEmpty) ...[
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
                            'DISCOVERED BLE DEVICES',
                            style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          ..._ble.discoveredDevices.map((d) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.devices, color: AppColors.infoBlue),
                              title: Text(d.name, style: AppTextStyles.title.copyWith(fontSize: 14)),
                              subtitle: Text('ID: ${d.id} · RSSI: ${d.rssi} dBm', style: AppTextStyles.caption),
                              trailing: isConnected && _ble.isSimulated
                                  ? const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20)
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Visual Communication Path
                  const CommunicationPathCard(currentStage: 2),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: AppColors.infoBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The victim phone uses Bluetooth Low Energy to send a compact SOS byte-packet to an ESP32 LoRa handheld, which relays it over miles of off-grid mesh.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                          ),
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
}
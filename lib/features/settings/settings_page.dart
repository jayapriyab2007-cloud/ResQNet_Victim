import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsPage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'Settings & System',
              subtitle: 'ResQNet protocol & operational status',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.offline_bolt, color: AppColors.successGreen),
                          title: const Text('Offline-First Architecture'),
                          subtitle: const Text('All SOS requests and messages are persisted locally before transmission attempt.'),
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        ListTile(
                          leading: const Icon(Icons.developer_mode, color: AppColors.infoBlue),
                          title: const Text('Communication Mode'),
                          subtitle: Text(AppConstants.simulationMode
                              ? 'Simulation Mode active (No physical ESP32 required for demo)'
                              : 'Physical Hardware Mode (ESP32 BLE active)'),
                          trailing: const SimulationBadge(),
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        const ListTile(
                          leading: Icon(Icons.security, color: AppColors.warningAmber),
                          title: Text('Privacy & LoRa Efficiency'),
                          subtitle: Text('Full medical data is never broadcasted over open radio; only compact emergency tokens.'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emergencyRedBright,
                      side: const BorderSide(color: AppColors.emergencyRed),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('LOG OUT'),
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

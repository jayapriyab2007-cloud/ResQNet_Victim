import 'package:flutter/material.dart';
import '../../core/services/emergency_service.dart';
import '../../models/user_profile.dart';
import 'sos_confirm_page.dart';

class EmergencyPage extends StatelessWidget {
  final String type;
  final UserProfile profile;
  final EmergencyService service;

  const EmergencyPage({
    super.key,
    required this.type,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return SosConfirmPage(
      service: service,
      profile: profile,
      existingEmergency: service.currentActive,
      initialType: type,
    );
  }
}

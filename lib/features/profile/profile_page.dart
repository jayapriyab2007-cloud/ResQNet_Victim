import 'package:flutter/material.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/user_profile.dart';
import '../../widgets/screen_header.dart';
import '../contacts/contacts_page.dart';
import '../handheld/handheld_page.dart';
import '../history/history_page.dart';
import '../medical/medical_page.dart';
import '../onboarding/onboarding_page.dart';

class ProfilePage extends StatefulWidget {
  final LocalStore store;
  final UserProfile profile;
  final VoidCallback onSaved;
  final VoidCallback? onLogout;

  const ProfilePage({
    super.key,
    required this.store,
    required this.profile,
    required this.onSaved,
    this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _emailController = TextEditingController(text: widget.profile.email);
    _dobController = TextEditingController(text: widget.profile.dob);
    _genderController = TextEditingController(text: widget.profile.gender);
    _addressController = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _savePersonal() async {
    setState(() => _isSaving = true);

    final updated = UserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      dob: _dobController.text.trim(),
      gender: _genderController.text.trim(),
      bloodGroup: widget.profile.bloodGroup,
      address: _addressController.text.trim(),
      emergencyContact: widget.profile.emergencyContact,
      medicalConditions: widget.profile.medicalConditions,
      allergies: widget.profile.allergies,
      medications: widget.profile.medications,
      deviceId: widget.profile.deviceId,
    );

    await widget.store.saveProfile(updated);
    widget.onSaved();

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personal profile saved.'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'Profile & Device',
              subtitle: 'Identity and rescue configuration',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Device Identity Card
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
                        Text('YOUR NAME', style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: AppTextStyles.title.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            hintText: 'Priya Sharma',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _infoChip('Device ID', widget.profile.deviceId),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _infoChip('Mesh Radio', 'SX1262 LoRa v2'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Dedicated Emergency Sections Menu
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _menuTile(
                          icon: Icons.medical_services_outlined,
                          title: 'Medical Information',
                          subtitle: widget.profile.bloodGroup.isNotEmpty
                              ? 'Blood: ${widget.profile.bloodGroup} · Conditions attached'
                              : 'Blood group, allergies, medications',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicalPage(
                                  store: widget.store,
                                  profile: widget.profile,
                                  onSaved: widget.onSaved,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        _menuTile(
                          icon: Icons.contact_emergency_outlined,
                          title: 'Emergency Contacts',
                          subtitle: 'People notified when SOS reaches a gateway',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ContactsPage(store: widget.store),
                              ),
                            );
                          },
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        _menuTile(
                          icon: Icons.history_rounded,
                          title: 'Incident History',
                          subtitle: 'View previous SOS alerts and logs',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HistoryPage(store: widget.store, isStandalone: true),
                              ),
                            );
                          },
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        _menuTile(
                          icon: Icons.bluetooth_audio,
                          title: 'BLE Handheld Link',
                          subtitle: 'Pair ESP32 / LoRa bridge device',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HandheldPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        _menuTile(
                          icon: Icons.menu_book_rounded,
                          title: 'How ResQNet Works',
                          subtitle: 'Replay multi-hop off-grid guide',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OnboardingPage(
                                  store: widget.store,
                                  onFinished: () => Navigator.pop(context),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Personal Information Section
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
                          'PERSONAL INFORMATION',
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _profileField('Phone Number', _phoneController, '+91 98765 43210', keyboardType: TextInputType.phone),
                        _profileField('Email Address', _emailController, 'name@domain.com', keyboardType: TextInputType.emailAddress),
                        _profileField('Date of Birth', _dobController, 'DD/MM/YYYY', keyboardType: TextInputType.datetime),
                        _profileField('Gender', _genderController, 'e.g. Female / Male / Other'),
                        _profileField('Home Address', _addressController, 'City, State, PIN', maxLines: 2),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _isSaving ? null : _savePersonal,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(_isSaving ? 'SAVING…' : 'SAVE PERSONAL DETAILS'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (widget.onLogout != null) ...[
                    OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergencyRedBright,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('LOG OUT'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'ResQNet v1.0.0+1 • Offline Emergency Protocol v1',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
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

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelCaps.copyWith(fontSize: 9.5)),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.title.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.infoBlue, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.title.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
    );
  }

  Widget _profileField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppTextStyles.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
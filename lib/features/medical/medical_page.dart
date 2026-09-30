import 'package:flutter/material.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/user_profile.dart';
import '../../widgets/screen_header.dart';

class MedicalPage extends StatefulWidget {
  final LocalStore store;
  final UserProfile profile;
  final VoidCallback onSaved;

  const MedicalPage({
    super.key,
    required this.store,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bloodController;
  late TextEditingController _allergiesController;
  late TextEditingController _conditionsController;
  late TextEditingController _medicationsController;

  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(text: widget.profile.age);
    _bloodController = TextEditingController(text: widget.profile.bloodGroup);
    _allergiesController = TextEditingController(text: widget.profile.allergies);
    _conditionsController = TextEditingController(text: widget.profile.medicalConditions);
    _medicationsController = TextEditingController(text: widget.profile.medications);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bloodController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = UserProfile(
      name: _nameController.text.trim(),
      phone: widget.profile.phone,
      email: widget.profile.email,
      dob: widget.profile.dob,
      age: _ageController.text.trim(),
      gender: widget.profile.gender,
      bloodGroup: _bloodController.text.trim(),
      address: widget.profile.address,
      emergencyContact: widget.profile.emergencyContact,
      medicalConditions: _conditionsController.text.trim(),
      allergies: _allergiesController.text.trim(),
      medications: _medicationsController.text.trim(),
      deviceId: widget.profile.deviceId,
    );

    await widget.store.saveProfile(updated);
    widget.onSaved();

    setState(() => _saved = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medical profile saved on device.'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blood = _bloodController.text.trim();
    final age = _ageController.text.trim();
    final hasAllergy = _allergiesController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Medical Information',
              subtitle: 'Critical rescue data stored locally',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Rescuer Summary Card
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
                          'RESCUER SUMMARY CARD',
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _chip('Blood Group', blood.isNotEmpty ? blood : '—'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _chip('Age', age.isNotEmpty ? age : '—'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _chip('Allergies', hasAllergy ? 'YES' : 'NONE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _inputField('Full Name', _nameController, 'e.g. Priya Sharma'),
                  _inputField('Age', _ageController, 'e.g. 28', keyboardType: TextInputType.number),
                  _inputField('Blood Group', _bloodController, 'e.g. O+, A+, B-'),
                  _inputField('Allergies', _allergiesController, 'e.g. Penicillin, Peanuts'),
                  _inputField('Medical Conditions', _conditionsController, 'e.g. Asthma, Diabetes'),
                  _inputField('Current Medications', _medicationsController, 'e.g. Salbutamol Inhaler'),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('SAVE MEDICAL PROFILE'),
                  ),

                  if (_saved) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successGreenBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Saved locally on this device. Emergency responders can access this data when your SOS is received.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: AppColors.successGreen),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.privacy_tip_outlined, size: 18, color: AppColors.infoBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Privacy Protection: LoRa packets carry only compact incident coordinates. Full medical details are never broadcasted in plain LoRa packets; they are retrieved securely by authorized rescue personnel.',
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

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelCaps.copyWith(fontSize: 9.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.title.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

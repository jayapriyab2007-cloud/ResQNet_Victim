import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/contact.dart';
import '../../widgets/screen_header.dart';

class ContactsPage extends StatefulWidget {
  final LocalStore store;

  const ContactsPage({super.key, required this.store});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.store.loadContacts();
    if (!mounted) return;
    setState(() {
      _contacts = list;
      _isLoading = false;
    });
  }

  Future<void> _addContact() async {
    final name = _nameController.text.trim();
    final relation = _relationController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least a name and phone number.')),
      );
      return;
    }

    final newContact = EmergencyContact(
      id: const Uuid().v4().substring(0, 8),
      name: name,
      relation: relation.isNotEmpty ? relation : 'Contact',
      phone: phone,
    );

    final updated = [..._contacts, newContact];
    await widget.store.saveContacts(updated);

    _nameController.clear();
    _relationController.clear();
    _phoneController.clear();

    if (!mounted) return;
    setState(() => _contacts = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact added.'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  Future<void> _deleteContact(String id) async {
    final updated = _contacts.where((c) => c.id != id).toList();
    await widget.store.saveContacts(updated);
    if (!mounted) return;
    setState(() => _contacts = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Emergency Contacts',
              subtitle: 'Notified when your SOS reaches a gateway',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      children: [
                        if (_contacts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Text(
                                'No contacts saved yet. Add at least one person who should be alerted.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary,
                              ),
                            ),
                          ),

                        ..._contacts.map((c) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person, color: AppColors.infoBlue, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.relation} · ${c.phone}',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteContact(c.id),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.emergencyRedBright, size: 20),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 18),

                        // Add Contact Form
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
                                'ADD EMERGENCY CONTACT',
                                style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'e.g. Ramesh Sharma',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _relationController,
                                decoration: const InputDecoration(
                                  labelText: 'Relationship',
                                  hintText: 'e.g. Brother, Spouse, Parent',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '+91 98765 43210',
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _addContact,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.emergencyRed,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                icon: const Icon(Icons.person_add, size: 20),
                                label: const Text('ADD CONTACT'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'These contacts are alerted through automated SMS/Notification once your emergency reaches a connected gateway edge or command center.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4),
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

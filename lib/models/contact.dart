class EmergencyContact {
  final String id;
  final String name;
  final String relation;
  final String phone;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relation': relation,
    'phone': phone,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    relation: j['relation'] ?? '',
    phone: j['phone'] ?? '',
  );
}

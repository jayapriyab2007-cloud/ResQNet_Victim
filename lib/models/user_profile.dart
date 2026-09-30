class UserProfile {
  String name;
  String phone;
  String email;
  String dob;
  String age;
  String gender;
  String bloodGroup;
  String address;
  String emergencyContact;
  String medicalConditions;
  String allergies;
  String medications;
  String deviceId;

  UserProfile({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.dob = '',
    this.age = '',
    this.gender = '',
    this.bloodGroup = '',
    this.address = '',
    this.emergencyContact = '',
    this.medicalConditions = '',
    this.allergies = '',
    this.medications = '',
    this.deviceId = 'RQN-7F42-A19',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'dob': dob,
    'age': age,
    'gender': gender,
    'blood_group': bloodGroup,
    'address': address,
    'emergency_contact': emergencyContact,
    'medical_conditions': medicalConditions,
    'allergies': allergies,
    'medications': medications,
    'device_id': deviceId,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'] ?? '',
    dob: j['dob'] ?? '',
    age: j['age'] ?? '',
    gender: j['gender'] ?? '',
    bloodGroup: j['blood_group'] ?? '',
    address: j['address'] ?? '',
    emergencyContact: j['emergency_contact'] ?? '',
    medicalConditions: j['medical_conditions'] ?? '',
    allergies: j['allergies'] ?? '',
    medications: j['medications'] ?? '',
    deviceId: j['device_id'] ?? 'RQN-7F42-A19',
  );
}

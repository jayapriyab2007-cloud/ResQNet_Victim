import '../core/constants/app_constants.dart';

class Emergency {
  final String emergencyId;
  final String messageId;
  final String victimId;
  final String source;
  final String type;
  final String severity;
  final int priority;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final int peopleAffected;
  final int battery;
  final DateTime timestamp;
  final String status;
  final int repeatedCount;
  final String communicationState;
  final String deliveryState;
  final String note;
  final DateTime? endedAt;
  final String contactNotified;
  final int stage; // 0..6 for timeline tracking

  const Emergency({
    required this.emergencyId,
    required this.messageId,
    required this.victimId,
    this.source = EmergencySource.mainSos,
    required this.type,
    required this.severity,
    required this.priority,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    required this.peopleAffected,
    required this.battery,
    required this.timestamp,
    required this.status,
    required this.repeatedCount,
    required this.communicationState,
    this.deliveryState = DeliveryState.queued,
    this.note = '',
    this.endedAt,
    this.contactNotified = 'ResQNet Gateway / Unit',
    this.stage = 0,
  });

  Emergency copyWith({
    String? emergencyId,
    String? messageId,
    String? victimId,
    String? source,
    String? type,
    String? severity,
    int? priority,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    int? peopleAffected,
    int? battery,
    DateTime? timestamp,
    String? status,
    int? repeatedCount,
    String? communicationState,
    String? deliveryState,
    String? note,
    DateTime? endedAt,
    String? contactNotified,
    int? stage,
  }) {
    return Emergency(
      emergencyId: emergencyId ?? this.emergencyId,
      messageId: messageId ?? this.messageId,
      victimId: victimId ?? this.victimId,
      source: source ?? this.source,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      battery: battery ?? this.battery,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      repeatedCount: repeatedCount ?? this.repeatedCount,
      communicationState: communicationState ?? this.communicationState,
      deliveryState: deliveryState ?? this.deliveryState,
      note: note ?? this.note,
      endedAt: endedAt ?? this.endedAt,
      contactNotified: contactNotified ?? this.contactNotified,
      stage: stage ?? this.stage,
    );
  }

  Map<String, dynamic> toJson() => {
    'emergency_id': emergencyId,
    'message_id': messageId,
    'victim_id': victimId,
    'source': source,
    'emergency_type': type,
    'type': type,
    'severity': severity,
    'priority': 'P$priority',
    'priority_level': priority,
    'latitude': latitude,
    'longitude': longitude,
    'gps_accuracy': gpsAccuracy,
    'people_affected': peopleAffected,
    'battery': battery,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'repeated_count': repeatedCount,
    'repeated_sos_count': repeatedCount,
    'communication_state': communicationState,
    'delivery_state': deliveryState,
    'note': note,
    if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
    'contact_notified': contactNotified,
    'stage': stage,
  };

  /// Compact packet tailored for LoRa / BLE transmission (no large medical data)
  Map<String, dynamic> toCompactPacket({int ttl = 10}) => {
    'protocol_version': AppConstants.protocolVersion,
    'message_id': messageId,
    'emergency_id': emergencyId,
    'victim_id': victimId,
    'source': source,
    'priority': priority,
    'priority_code': 'P$priority',
    'emergency_type': type,
    'type': type,
    'severity': severity,
    'latitude': latitude != null ? double.parse(latitude!.toStringAsFixed(5)) : null,
    'longitude': longitude != null ? double.parse(longitude!.toStringAsFixed(5)) : null,
    'gps_accuracy': gpsAccuracy?.round(),
    'people_affected': peopleAffected,
    'battery': battery,
    'timestamp': timestamp.toIso8601String(),
    'repeated_sos_count': repeatedCount,
    'repeated_count': repeatedCount,
    'communication_state': communicationState,
    'delivery_state': deliveryState,
    'ttl': ttl,
  };

  factory Emergency.fromJson(Map<String, dynamic> j) => Emergency(
    emergencyId: j['emergency_id'] ?? '',
    messageId: j['message_id'] ?? '',
    victimId: j['victim_id'] ?? '',
    source: j['source'] ?? EmergencySource.mainSos,
    type: j['emergency_type'] ?? j['type'] ?? EmergencyType.other,
    severity: j['severity'] ?? Severity.critical,
    priority: j['priority_level'] is int
        ? j['priority_level']
        : (j['priority'] is int
            ? j['priority']
            : (j['priority'] is String && (j['priority'] as String).startsWith('P')
                ? int.tryParse((j['priority'] as String).substring(1)) ?? 1
                : int.tryParse('${j['priority'] ?? 1}') ?? 1)),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    gpsAccuracy: (j['gps_accuracy'] as num?)?.toDouble(),
    peopleAffected: j['people_affected'] ?? 1,
    battery: j['battery'] ?? -1,
    timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    status: j['status'] ?? 'SOS SENT',
    repeatedCount: j['repeated_sos_count'] ?? j['repeated_count'] ?? 1,
    communicationState: j['communication_state'] ?? CommunicationState.localSaved,
    deliveryState: j['delivery_state'] ?? DeliveryState.queued,
    note: j['note'] ?? '',
    endedAt: j['ended_at'] != null ? DateTime.tryParse(j['ended_at']) : null,
    contactNotified: j['contact_notified'] ?? 'ResQNet Gateway / Unit',
    stage: j['stage'] ?? 0,
  );
}

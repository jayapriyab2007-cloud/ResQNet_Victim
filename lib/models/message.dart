enum MessageStatus { queued, relaying, delivered, failed }

class EmergencyMessage {
  final String id;
  final String from; // 'me' | 'rescuer'
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final int attempts;

  const EmergencyMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.queued,
    this.attempts = 0,
  });

  EmergencyMessage copyWith({
    String? id,
    String? from,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    int? attempts,
  }) {
    return EmergencyMessage(
      id: id ?? this.id,
      from: from ?? this.from,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
  };

  factory EmergencyMessage.fromJson(Map<String, dynamic> j) => EmergencyMessage(
    id: j['id'] ?? '',
    from: j['from'] ?? 'me',
    text: j['text'] ?? '',
    timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    status: MessageStatus.values.firstWhere(
      (e) => e.name == (j['status'] ?? 'queued'),
      orElse: () => MessageStatus.queued,
    ),
    attempts: j['attempts'] ?? 0,
  );
}

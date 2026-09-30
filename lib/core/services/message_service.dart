import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../models/message.dart';
import '../storage/local_store.dart';
import 'ble_service.dart';
import 'connectivity_service.dart';

class MessageService {
  final LocalStore store;
  final BleService ble;
  final ConnectivityService connectivity;

  final _controller = StreamController<List<EmergencyMessage>>.broadcast();
  Stream<List<EmergencyMessage>> get stream => _controller.stream;

  List<EmergencyMessage> _messages = [];
  List<EmergencyMessage> get messages => List.unmodifiable(_messages);

  Timer? _retryTimer;

  static const List<String> quickReplies = [
    'I am safe',
    'I am injured',
    'I need medical help',
    'I cannot move',
    'I hear rescuers nearby',
    'Battery is low',
  ];

  MessageService({
    required this.store,
    required this.ble,
    required this.connectivity,
  }) {
    _init();
  }

  Future<void> _init() async {
    _messages = await store.loadMessages();
    _controller.add(_messages);

    // If there are queued messages from past sessions, flush them
    flushQueue();

    // Start periodic retry loop
    _retryTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      flushQueue();
    });
  }

  Future<void> sendMessage(String text, {String from = 'me'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msg = EmergencyMessage(
      id: const Uuid().v4().substring(0, 8),
      from: from,
      text: trimmed,
      timestamp: DateTime.now(),
      status: from == 'me' ? MessageStatus.queued : MessageStatus.delivered,
      attempts: 0,
    );

    _messages = [..._messages, msg];
    await store.saveMessages(_messages);
    _controller.add(_messages);

    if (from == 'me') {
      _attemptSend(msg.id);
    }
  }

  Future<void> retryNow() async {
    flushQueue();
  }

  Future<void> flushQueue() async {
    final queued = _messages.where((m) => m.from == 'me' && m.status == MessageStatus.queued).toList();
    for (final m in queued) {
      _attemptSend(m.id);
    }
  }

  Future<void> _attemptSend(String id) async {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final current = _messages[index];

    // Mark as relaying
    _updateStatus(id, MessageStatus.relaying, current.attempts + 1);

    // Attempt BLE / Mesh transmission
    final bleSent = await ble.sendPacket({
      'type': 'MESSAGE',
      'id': current.id,
      'text': current.text,
      'timestamp': current.timestamp.toIso8601String(),
    });

    final hasNet = await connectivity.hasInternet();

    if (bleSent || hasNet || ble.connected || ble.isSimulated) {
      await Future.delayed(const Duration(milliseconds: 1400));
      _updateStatus(id, MessageStatus.delivered, current.attempts + 1);

      // In simulation mode, if victim sent a message, simulate rescuer acknowledgment after a short delay
      if (ble.isSimulated && Random().nextBool()) {
        Future.delayed(const Duration(seconds: 4), () {
          sendMessage(
            'Rescue Unit acknowledged: "${current.text.length > 25 ? '${current.text.substring(0, 25)}…' : current.text}". Stay in your position.',
            from: 'rescuer',
          );
        });
      }
    } else {
      // Offline & no BLE connection: keep in queued with exponential delay
      _updateStatus(id, MessageStatus.queued, current.attempts + 1);
    }
  }

  void _updateStatus(String id, MessageStatus status, int attempts) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final updated = _messages[idx].copyWith(status: status, attempts: attempts);
      _messages[idx] = updated;
      store.saveMessages(_messages);
      _controller.add(_messages);
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _controller.close();
  }
}

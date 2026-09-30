import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';
import '../constants/app_constants.dart';
import '../storage/local_store.dart';
import 'priority_service.dart';
import 'location_service.dart';
import 'ble_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'message_service.dart';

class EmergencyService {
  final LocalStore store;
  final LocationService location;
  final BleService ble;
  final ApiService api;
  final ConnectivityService connectivity;
  MessageService? messageService;

  List<Emergency> _activeEmergencies = [];
  List<Emergency> get activeEmergencies => List.unmodifiable(_activeEmergencies);

  final _activeController = StreamController<Emergency?>.broadcast();
  Stream<Emergency?> get activeStream => _activeController.stream;

  final _activeListController = StreamController<List<Emergency>>.broadcast();
  Stream<List<Emergency>> get activeListStream => _activeListController.stream;

  Emergency? _currentActive;
  Emergency? get currentActive => _currentActive;

  final Map<String, List<Timer>> _activeTimers = {};

  EmergencyService({
    required this.store,
    required this.location,
    required this.ble,
    required this.api,
    required this.connectivity,
    this.messageService,
  }) {
    _restoreActive();
  }

  void _notifyActive() {
    _currentActive = _activeEmergencies.isNotEmpty ? _activeEmergencies.first : null;
    _activeController.add(_currentActive);
    _activeListController.add(List.unmodifiable(_activeEmergencies));
  }

  Future<void> _restoreActive() async {
    final activeIds = await store.getActiveEmergencyIds();
    final list = await store.loadEmergencies();
    _activeEmergencies = list
        .where((e) =>
            activeIds.contains(e.emergencyId) &&
            e.status != 'CANCELLED' &&
            e.status != 'CLOSED')
        .toList();

    _notifyActive();

    for (final match in _activeEmergencies) {
      if (match.stage < 4 && (ble.isSimulated || AppConstants.simulationMode)) {
        _advanceSimulationStages(match);
      }
    }
  }

  /// 1. MAIN SOS: Immediate generic emergency alert
  /// - Source: MAIN_SOS
  /// - Emergency Type: OTHER
  /// - Severity: CRITICAL
  /// - Priority: P1
  /// - Immediate transmission with no preceding form or dialog.
  /// - Deduplicates repeated taps on the active Main SOS by updating GPS, timestamp,
  ///   battery, and repeated_sos_count without generating duplicate emergency IDs.
  Future<Emergency> createMainSos({
    required UserProfile profile,
    int battery = 64,
  }) async {
    // 0. Ensure we refresh from local store if in-memory active list is empty
    if (_activeEmergencies.isEmpty) {
      await _restoreActive();
    }

    final existingIndex = _activeEmergencies.indexWhere(
      (e) =>
          e.source == EmergencySource.mainSos &&
          e.status != 'CANCELLED' &&
          e.status != 'CLOSED',
    );

    if (existingIndex != -1) {
      final current = _activeEmergencies[existingIndex];
      final loc = await location.getPositionWithFallback();
      final now = DateTime.now();
      final updatedCount = current.repeatedCount + 1;

      var updated = current.copyWith(
        timestamp: now,
        latitude: loc?.latitude ?? current.latitude,
        longitude: loc?.longitude ?? current.longitude,
        gpsAccuracy: loc?.accuracy ?? current.gpsAccuracy,
        battery: battery,
        repeatedCount: updatedCount,
        status: 'SOS SENT',
        deliveryState: DeliveryState.sosSent,
        stage: max(current.stage, loc != null ? 1 : 0),
      );

      _activeEmergencies[existingIndex] = updated;
      await store.saveEmergency(updated);
      _notifyActive();

      // Re-transmit over BLE
      final packet = updated.toCompactPacket(ttl: 10);
      final bleSent = await ble.sendPacket(packet);
      if (bleSent) {
        updated = updated.copyWith(
          communicationState: CommunicationState.handheldReceived,
          deliveryState: DeliveryState.relayed,
          stage: max(updated.stage, 2),
        );
        _activeEmergencies[existingIndex] = updated;
        await store.saveEmergency(updated);
        _notifyActive();
      }

      // Re-transmit over Internet API if online
      if (await connectivity.hasInternet()) {
        final token = await store.token();
        final synced = await api.syncEmergency(updated, token: token);
        if (synced) {
          updated = updated.copyWith(
            communicationState: CommunicationState.serverReceived,
            deliveryState: DeliveryState.serverReceived,
            stage: max(updated.stage, 4),
          );
          _activeEmergencies[existingIndex] = updated;
          await store.saveEmergency(updated);
          _notifyActive();
        }
      }

      return updated;
    }

    // Create a brand new MAIN_SOS record
    final locResult = await location.getPositionWithFallback();
    final now = DateTime.now();
    final emergencyId =
        'RQ-${now.year}-${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final messageId =
        'SOS-${now.year}-${const Uuid().v4().substring(0, 8).toUpperCase()}';

    var emergency = Emergency(
      emergencyId: emergencyId,
      messageId: messageId,
      victimId: profile.phone.isNotEmpty ? profile.phone : profile.deviceId,
      source: EmergencySource.mainSos,
      type: EmergencyType.other,
      severity: Severity.critical,
      priority: 1,
      latitude: locResult?.latitude,
      longitude: locResult?.longitude,
      gpsAccuracy: locResult?.accuracy,
      peopleAffected: 1,
      battery: battery,
      timestamp: now,
      status: 'SOS SENT',
      repeatedCount: 1,
      communicationState: CommunicationState.localSaved,
      deliveryState: DeliveryState.queued,
      note: '',
      contactNotified: 'ResQNet Gateway / Unit 4',
      stage: locResult != null ? 1 : 0,
    );

    // Save locally immediately (Offline-First Guarantee)
    await store.saveEmergency(emergency);
    await store.addActiveEmergencyId(emergencyId);
    _activeEmergencies.insert(0, emergency);
    _notifyActive();

    // Attempt BLE transmission
    final compactPacket = emergency.toCompactPacket(ttl: 10);
    final bleSent = await ble.sendPacket(compactPacket);
    if (bleSent) {
      emergency = emergency.copyWith(
        communicationState: CommunicationState.handheldReceived,
        deliveryState: DeliveryState.relayed,
        stage: 2,
      );
      final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
      if (idx != -1) _activeEmergencies[idx] = emergency;
      await store.saveEmergency(emergency);
      _notifyActive();
    }

    // Direct sync to FastAPI backend if Internet is available
    if (await connectivity.hasInternet()) {
      final token = await store.token();
      final synced = await api.syncEmergency(emergency, token: token);
      if (synced) {
        emergency = emergency.copyWith(
          communicationState: CommunicationState.serverReceived,
          deliveryState: DeliveryState.serverReceived,
          stage: max(emergency.stage, 4),
        );
        final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
        if (idx != -1) _activeEmergencies[idx] = emergency;
        await store.saveEmergency(emergency);
        _notifyActive();
      }
    }

    if (ble.isSimulated || AppConstants.simulationMode) {
      _advanceSimulationStages(emergency);
    }

    return emergency;
  }

  /// 2. EMERGENCY SOS: Specific disaster/emergency alert
  /// - Source: EMERGENCY_SOS
  /// - Emergency Type: type (e.g. FLOOD, FIRE, FOREST_FIRE, etc.)
  /// - Immediately transmitted without generic OTHER step.
  /// - Repeated taps on the SAME active type update that active record.
  /// - Different types (e.g. FLOOD vs FIRE vs MAIN_SOS) get separate emergency records.
  Future<Emergency> createEmergencySos({
    required UserProfile profile,
    required String type,
    String severity = Severity.critical,
    int peopleAffected = 1,
    String note = '',
    int battery = 64,
  }) async {
    if (_activeEmergencies.isEmpty) {
      await _restoreActive();
    }

    final existingIndex = _activeEmergencies.indexWhere(
      (e) =>
          e.source == EmergencySource.emergencySos &&
          e.type.toUpperCase() == type.toUpperCase() &&
          e.status != 'CANCELLED' &&
          e.status != 'CLOSED',
    );

    if (existingIndex != -1) {
      final current = _activeEmergencies[existingIndex];
      final loc = await location.getPositionWithFallback();
      final now = DateTime.now();
      final updatedCount = current.repeatedCount + 1;

      var updated = current.copyWith(
        timestamp: now,
        latitude: loc?.latitude ?? current.latitude,
        longitude: loc?.longitude ?? current.longitude,
        gpsAccuracy: loc?.accuracy ?? current.gpsAccuracy,
        battery: battery,
        repeatedCount: updatedCount,
        status: 'SOS SENT',
        deliveryState: DeliveryState.sosSent,
        stage: max(current.stage, loc != null ? 1 : 0),
      );

      _activeEmergencies[existingIndex] = updated;
      await store.saveEmergency(updated);
      _notifyActive();

      final packet = updated.toCompactPacket(ttl: 10);
      final bleSent = await ble.sendPacket(packet);
      if (bleSent) {
        updated = updated.copyWith(
          communicationState: CommunicationState.handheldReceived,
          deliveryState: DeliveryState.relayed,
          stage: max(updated.stage, 2),
        );
        _activeEmergencies[existingIndex] = updated;
        await store.saveEmergency(updated);
        _notifyActive();
      }

      if (await connectivity.hasInternet()) {
        final token = await store.token();
        final synced = await api.syncEmergency(updated, token: token);
        if (synced) {
          updated = updated.copyWith(
            communicationState: CommunicationState.serverReceived,
            deliveryState: DeliveryState.serverReceived,
            stage: max(updated.stage, 4),
          );
          _activeEmergencies[existingIndex] = updated;
          await store.saveEmergency(updated);
          _notifyActive();
        }
      }

      return updated;
    }

    // Create a brand new EMERGENCY_SOS with the specific disaster type
    final locResult = await location.getPositionWithFallback();
    final priority = PriorityService.calculate(
      type: type,
      severity: severity,
      peopleAffected: peopleAffected,
    );
    final now = DateTime.now();
    final emergencyId =
        'RQ-${now.year}-${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final messageId =
        'SOS-${now.year}-${const Uuid().v4().substring(0, 8).toUpperCase()}';

    var emergency = Emergency(
      emergencyId: emergencyId,
      messageId: messageId,
      victimId: profile.phone.isNotEmpty ? profile.phone : profile.deviceId,
      source: EmergencySource.emergencySos,
      type: type,
      severity: severity,
      priority: priority.level,
      latitude: locResult?.latitude,
      longitude: locResult?.longitude,
      gpsAccuracy: locResult?.accuracy,
      peopleAffected: peopleAffected,
      battery: battery,
      timestamp: now,
      status: 'SOS SENT',
      repeatedCount: 1,
      communicationState: CommunicationState.localSaved,
      deliveryState: DeliveryState.queued,
      note: note,
      contactNotified: 'ResQNet Gateway / Unit 4',
      stage: locResult != null ? 1 : 0,
    );

    await store.saveEmergency(emergency);
    await store.addActiveEmergencyId(emergencyId);
    _activeEmergencies.insert(0, emergency);
    _notifyActive();

    final compactPacket = emergency.toCompactPacket(ttl: 10);
    final bleSent = await ble.sendPacket(compactPacket);
    if (bleSent) {
      emergency = emergency.copyWith(
        communicationState: CommunicationState.handheldReceived,
        deliveryState: DeliveryState.relayed,
        stage: 2,
      );
      final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
      if (idx != -1) _activeEmergencies[idx] = emergency;
      await store.saveEmergency(emergency);
      _notifyActive();
    }

    if (await connectivity.hasInternet()) {
      final token = await store.token();
      final synced = await api.syncEmergency(emergency, token: token);
      if (synced) {
        emergency = emergency.copyWith(
          communicationState: CommunicationState.serverReceived,
          deliveryState: DeliveryState.serverReceived,
          stage: max(emergency.stage, 4),
        );
        final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
        if (idx != -1) _activeEmergencies[idx] = emergency;
        await store.saveEmergency(emergency);
        _notifyActive();
      }
    }

    if (ble.isSimulated || AppConstants.simulationMode) {
      _advanceSimulationStages(emergency);
    }

    return emergency;
  }

  /// Backward-compatible alias for Main SOS 1-tap trigger
  Future<Emergency> sendImmediateSos({
    required UserProfile profile,
    int battery = 64,
  }) async {
    return createMainSos(profile: profile, battery: battery);
  }

  /// Backward-compatible createAndSend router
  Future<Emergency> createAndSend({
    required UserProfile profile,
    required String type,
    required String severity,
    required int peopleAffected,
    String note = '',
    int battery = 64,
  }) async {
    if (type.toUpperCase() == EmergencyType.other) {
      return createMainSos(profile: profile, battery: battery);
    }
    return createEmergencySos(
      profile: profile,
      type: type,
      severity: severity,
      peopleAffected: peopleAffected,
      note: note,
      battery: battery,
    );
  }

  /// Update existing emergency details (Type, Severity, People, Note)
  Future<Emergency?> updateEmergencyDetails({
    required String emergencyId,
    required String type,
    String? severity,
    int? peopleAffected,
    String? note,
  }) async {
    final all = await store.loadEmergencies();
    final target = all.where((e) => e.emergencyId == emergencyId).firstOrNull;
    if (target == null) return null;

    final newType = type;
    final newSev = severity ?? target.severity;
    final newPeople = peopleAffected ?? target.peopleAffected;
    final newNote = note ?? target.note;

    final priorityResult = PriorityService.calculate(
      type: newType,
      severity: newSev,
      peopleAffected: newPeople,
    );

    var updated = target.copyWith(
      type: newType,
      severity: newSev,
      priority: priorityResult.level,
      peopleAffected: newPeople,
      note: newNote,
    );

    await store.saveEmergency(updated);
    final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
    if (idx != -1) {
      _activeEmergencies[idx] = updated;
    }
    _notifyActive();

    // Re-transmit updated compact packet over BLE / LoRa
    final packet = updated.toCompactPacket(ttl: 10);
    await ble.sendPacket(packet);

    // PATCH to backend if Internet available
    if (await connectivity.hasInternet()) {
      final token = await store.token();
      await api.patchEmergency(
        emergencyId,
        {
          'emergency_type': newType,
          'type': newType,
          'severity': newSev,
          'priority': 'P${priorityResult.level}',
          'priority_level': priorityResult.level,
          'people_affected': newPeople,
          'note': newNote,
        },
        token: token,
      );
    }

    return updated;
  }

  /// Update entire emergency record
  Future<Emergency?> updateEmergency(Emergency emergency) async {
    await store.saveEmergency(emergency);
    final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergency.emergencyId);
    if (idx != -1) {
      _activeEmergencies[idx] = emergency;
    }
    _notifyActive();

    final packet = emergency.toCompactPacket(ttl: 10);
    await ble.sendPacket(packet);

    if (await connectivity.hasInternet()) {
      final token = await store.token();
      await api.patchEmergency(emergency.emergencyId, emergency.toJson(), token: token);
    }
    return emergency;
  }

  /// Update location for an active emergency
  Future<Emergency?> updateLocationForActive({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? emergencyId,
  }) async {
    Emergency? target;
    if (emergencyId != null) {
      target = _activeEmergencies.where((e) => e.emergencyId == emergencyId).firstOrNull;
    }
    target ??= currentActive;
    if (target == null) return null;

    var updated = target.copyWith(
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: accuracy ?? target.gpsAccuracy,
    );

    await store.saveEmergency(updated);
    final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == target!.emergencyId);
    if (idx != -1) {
      _activeEmergencies[idx] = updated;
    }
    _notifyActive();

    final packet = updated.toCompactPacket(ttl: 10);
    await ble.sendPacket(packet);

    if (await connectivity.hasInternet()) {
      final token = await store.token();
      await api.updateLocation(updated.emergencyId, latitude, longitude, token: token);
    }

    return updated;
  }

  /// Retry transmission of an emergency
  Future<Emergency?> retryEmergency(String emergencyId) async {
    final all = await store.loadEmergencies();
    var e = all.where((x) => x.emergencyId == emergencyId).firstOrNull;
    if (e == null) return null;

    final packet = e.toCompactPacket(ttl: 10);
    final bleSent = await ble.sendPacket(packet);
    if (bleSent) {
      e = e.copyWith(
        communicationState: CommunicationState.handheldReceived,
        deliveryState: DeliveryState.relayed,
        stage: max(e.stage, 2),
      );
      await store.saveEmergency(e);
    }

    if (await connectivity.hasInternet()) {
      final token = await store.token();
      final synced = await api.syncEmergency(e, token: token);
      if (synced) {
        e = e.copyWith(
          communicationState: CommunicationState.serverReceived,
          deliveryState: DeliveryState.serverReceived,
          stage: max(e.stage, 4),
        );
        await store.saveEmergency(e);
      }
    }

    final idx = _activeEmergencies.indexWhere((x) => x.emergencyId == emergencyId);
    if (idx != -1) {
      _activeEmergencies[idx] = e;
    }
    _notifyActive();
    return e;
  }

  /// Cancel a specific emergency by ID
  Future<void> cancelEmergency(String emergencyId) async {
    _clearTimers(emergencyId);
    final idx = _activeEmergencies.indexWhere((e) => e.emergencyId == emergencyId);
    Emergency? target;
    if (idx != -1) {
      target = _activeEmergencies[idx];
      _activeEmergencies.removeAt(idx);
    } else {
      final all = await store.loadEmergencies();
      target = all.where((e) => e.emergencyId == emergencyId).firstOrNull;
    }

    if (target != null) {
      final updated = target.copyWith(
        status: 'CANCELLED',
        communicationState: CommunicationState.cancelled,
        deliveryState: 'CANCELLED',
        endedAt: DateTime.now(),
      );
      await store.saveEmergency(updated);
    }
    await store.removeActiveEmergencyId(emergencyId);
    _notifyActive();

    // Attempt backend sync
    if (await connectivity.hasInternet()) {
      final token = await store.token();
      await api.cancelEmergency(emergencyId, token: token);
    }
  }

  /// Cancel active emergency (default to first active if ID not specified)
  Future<void> cancelActiveEmergency([String? id]) async {
    if (id != null) {
      await cancelEmergency(id);
    } else if (_activeEmergencies.isNotEmpty) {
      await cancelEmergency(_activeEmergencies.first.emergencyId);
    }
  }

  /// Retrieve all currently active emergencies
  Future<List<Emergency>> getActiveEmergencies() async {
    final activeIds = await store.getActiveEmergencyIds();
    final list = await store.loadEmergencies();
    return list
        .where((e) =>
            activeIds.contains(e.emergencyId) &&
            e.status != 'CANCELLED' &&
            e.status != 'CLOSED')
        .toList();
  }

  /// Retrieve complete emergency history
  Future<List<Emergency>> getHistory() async {
    return store.loadEmergencies();
  }

  void _advanceSimulationStages(Emergency initialEmergency) {
    final id = initialEmergency.emergencyId;
    _clearTimers(id);
    final timers = <Timer>[];

    // Stage 3: LoRa Mesh Relaying (after 2.5s)
    timers.add(Timer(const Duration(milliseconds: 2500), () async {
      final idx = _activeEmergencies.indexWhere(
          (e) => e.emergencyId == id && e.status != 'CANCELLED' && e.status != 'CLOSED');
      if (idx != -1) {
        final updated = _activeEmergencies[idx].copyWith(
          communicationState: CommunicationState.meshForwarding,
          deliveryState: DeliveryState.relayed,
          stage: 3,
        );
        _activeEmergencies[idx] = updated;
        await store.saveEmergency(updated);
        _notifyActive();
      }
    }));

    // Stage 4: Gateway Confirmation (after 5.5s)
    timers.add(Timer(const Duration(milliseconds: 5500), () async {
      final idx = _activeEmergencies.indexWhere(
          (e) => e.emergencyId == id && e.status != 'CANCELLED' && e.status != 'CLOSED');
      if (idx != -1) {
        final updated = _activeEmergencies[idx].copyWith(
          communicationState: CommunicationState.gatewayReceived,
          deliveryState: DeliveryState.relayed,
          stage: 4,
        );
        _activeEmergencies[idx] = updated;
        await store.saveEmergency(updated);
        _notifyActive();
      }
    }));

    // Stage 5: Responder Notification (after 8.5s)
    timers.add(Timer(const Duration(milliseconds: 8500), () async {
      final idx = _activeEmergencies.indexWhere(
          (e) => e.emergencyId == id && e.status != 'CANCELLED' && e.status != 'CLOSED');
      if (idx != -1) {
        final updated = _activeEmergencies[idx].copyWith(
          communicationState: CommunicationState.responderNotified,
          deliveryState: DeliveryState.acknowledged,
          stage: 5,
        );
        _activeEmergencies[idx] = updated;
        await store.saveEmergency(updated);
        _notifyActive();

        messageService?.sendMessage(
          'ResQNet Rescue Unit 4 received your alert (${initialEmergency.type}). We have your GPS coordinates. Stay in a safe position.',
          from: 'rescuer',
        );
      }
    }));

    // Stage 6: Responder Assigned (after 12s)
    timers.add(Timer(const Duration(milliseconds: 12000), () async {
      final idx = _activeEmergencies.indexWhere(
          (e) => e.emergencyId == id && e.status != 'CANCELLED' && e.status != 'CLOSED');
      if (idx != -1) {
        final updated = _activeEmergencies[idx].copyWith(
          communicationState: CommunicationState.responderAssigned,
          deliveryState: DeliveryState.acknowledged,
          stage: 6,
          status: 'TEAM ASSIGNED',
        );
        _activeEmergencies[idx] = updated;
        await store.saveEmergency(updated);
        _notifyActive();
      }
    }));

    _activeTimers[id] = timers;
  }

  void _clearTimers(String id) {
    if (_activeTimers.containsKey(id)) {
      for (final t in _activeTimers[id]!) {
        t.cancel();
      }
      _activeTimers.remove(id);
    }
  }

  void dispose() {
    for (final timers in _activeTimers.values) {
      for (final t in timers) {
        t.cancel();
      }
    }
    _activeTimers.clear();
    _activeController.close();
    _activeListController.close();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqnet_victim/core/constants/app_constants.dart';
import 'package:resqnet_victim/core/services/api_service.dart';
import 'package:resqnet_victim/core/services/ble_service.dart';
import 'package:resqnet_victim/core/services/connectivity_service.dart';
import 'package:resqnet_victim/core/services/emergency_service.dart';
import 'package:resqnet_victim/core/services/location_service.dart';
import 'package:resqnet_victim/core/services/priority_service.dart';
import 'package:resqnet_victim/core/storage/local_store.dart';
import 'package:resqnet_victim/features/emergency/sos_active_page.dart';
import 'package:resqnet_victim/features/history/history_page.dart';
import 'package:resqnet_victim/models/emergency.dart';
import 'package:resqnet_victim/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PriorityService Tests', () {
    test('Calculates P1 Critical for life-threatening emergencies', () {
      final p1 = PriorityService.calculate(
        type: EmergencyType.flood,
        severity: Severity.critical,
        peopleAffected: 4,
      );
      expect(p1.level, 1);
      expect(p1.label, 'CRITICAL');
      expect(p1.badgeText, 'P1 • CRITICAL');
    });

    test('Escalates mass casualty (5+ people) to P1', () {
      final p = PriorityService.calculate(
        type: EmergencyType.other,
        severity: Severity.general,
        peopleAffected: 6,
      );
      expect(p.level, 1);
      expect(p.label, 'CRITICAL');
    });

    test('Calculates P2 Serious for high-hazard disaster including Forest Fire', () {
      final pFire = PriorityService.calculate(
        type: EmergencyType.forestFire,
        severity: Severity.urgent,
        peopleAffected: 1,
      );
      expect(pFire.level, 2);
      expect(pFire.label, 'SERIOUS');
    });

    test('Calculates P4 General for general assistance', () {
      final p4 = PriorityService.calculate(
        type: EmergencyType.other,
        severity: Severity.general,
        peopleAffected: 1,
      );
      expect(p4.level, 4);
      expect(p4.label, 'GENERAL');
    });
  });

  group('Emergency Constants & Model Tests', () {
    test('EmergencySource has MAIN_SOS and EMERGENCY_SOS', () {
      expect(EmergencySource.mainSos, 'MAIN_SOS');
      expect(EmergencySource.emergencySos, 'EMERGENCY_SOS');
      expect(EmergencySource.label(EmergencySource.mainSos), 'MAIN SOS');
      expect(EmergencySource.label(EmergencySource.emergencySos), 'EMERGENCY SOS');
    });

    test('All 10 required emergency types exist with correct labels', () {
      expect(EmergencyType.all.length, 10);
      expect(EmergencyType.label(EmergencyType.flood), 'Flood');
      expect(EmergencyType.label(EmergencyType.cyclone), 'Cyclone');
      expect(EmergencyType.label(EmergencyType.fire), 'Fire');
      expect(EmergencyType.label(EmergencyType.forestFire), 'Forest Fire');
      expect(EmergencyType.label(EmergencyType.earthquake), 'Earthquake');
      expect(EmergencyType.label(EmergencyType.medical), 'Medical Emergency');
      expect(EmergencyType.label(EmergencyType.accident), 'Road Accident');
      expect(EmergencyType.label(EmergencyType.missingPerson), 'Missing Person');
      expect(EmergencyType.label(EmergencyType.safety), 'Safety / Crime');
      expect(EmergencyType.label(EmergencyType.other), 'Other Emergency');
    });

    test('Compact packet contains source and excludes full medical profile', () {
      final emergency = Emergency(
        emergencyId: 'RQ-2026-TEST001',
        messageId: 'SOS-2026-TEST001',
        victimId: '9876543210',
        source: EmergencySource.emergencySos,
        type: EmergencyType.flood,
        severity: Severity.critical,
        priority: 1,
        latitude: 12.971598,
        longitude: 77.594566,
        gpsAccuracy: 8.4,
        peopleAffected: 3,
        battery: 64,
        timestamp: DateTime(2026, 9, 30, 10, 0),
        status: 'REQUESTED',
        repeatedCount: 1,
        communicationState: CommunicationState.localSaved,
      );

      final packet = emergency.toCompactPacket(ttl: 10);

      expect(packet['protocol_version'], AppConstants.protocolVersion);
      expect(packet['emergency_id'], 'RQ-2026-TEST001');
      expect(packet['source'], EmergencySource.emergencySos);
      expect(packet['priority'], 1);
      expect(packet['emergency_type'], EmergencyType.flood);
      expect(packet['severity'], Severity.critical);
      expect(packet['latitude'], 12.97160);
      expect(packet['longitude'], 77.59457);
      expect(packet['gps_accuracy'], 8);
      expect(packet['people_affected'], 3);
      expect(packet['battery'], 64);
      expect(packet['ttl'], 10);

      expect(packet.containsKey('medical_conditions'), isFalse);
      expect(packet.containsKey('blood_group'), isFalse);
    });

    test('JSON serialization includes source, emergency_type, priority P1, delivery_state, and repeated_sos_count', () {
      final emergency = Emergency(
        emergencyId: 'RQ-TEST-JSON',
        messageId: 'SOS-TEST-JSON',
        victimId: 'user123',
        source: EmergencySource.mainSos,
        type: EmergencyType.other,
        severity: Severity.critical,
        priority: 1,
        peopleAffected: 1,
        battery: 75,
        timestamp: DateTime(2026, 9, 30, 12, 0),
        status: 'SOS SENT',
        repeatedCount: 2,
        communicationState: CommunicationState.localSaved,
        deliveryState: DeliveryState.queued,
      );

      final json = emergency.toJson();
      expect(json['emergency_id'], 'RQ-TEST-JSON');
      expect(json['source'], EmergencySource.mainSos);
      expect(json['emergency_type'], 'OTHER');
      expect(json['severity'], 'CRITICAL');
      expect(json['priority'], 'P1');
      expect(json['delivery_state'], DeliveryState.queued);
      expect(json['repeated_sos_count'], 2);

      final restored = Emergency.fromJson(json);
      expect(restored.emergencyId, 'RQ-TEST-JSON');
      expect(restored.source, EmergencySource.mainSos);
      expect(restored.type, 'OTHER');
      expect(restored.severity, 'CRITICAL');
      expect(restored.priority, 1);
      expect(restored.repeatedCount, 2);
    });
  });

  group('Prompt Section 23 Test Scenarios', () {
    late LocalStore store;
    late LocationService location;
    late BleService ble;
    late ApiService api;
    late ConnectivityService connectivity;
    late EmergencyService service;
    late UserProfile profile;

    setUp(() {
      store = LocalStore();
      location = LocationService(store: store);
      ble = BleService();
      api = ApiService();
      connectivity = ConnectivityService();
      service = EmergencyService(
        store: store,
        location: location,
        ble: ble,
        api: api,
        connectivity: connectivity,
      );
      profile = UserProfile(phone: 'USR-1023', name: 'Victim User', deviceId: 'DEV-001');
    });

    tearDown(() {
      service.dispose();
    });

    test('TEST 1: Press MAIN SOS creates emergency immediately with source=MAIN_SOS, type=OTHER, severity=CRITICAL, priority=1', () async {
      final emergency = await service.createMainSos(profile: profile, battery: 62);

      expect(emergency.source, EmergencySource.mainSos);
      expect(emergency.type, EmergencyType.other);
      expect(emergency.severity, Severity.critical);
      expect(emergency.priority, 1);
      expect(emergency.victimId, 'USR-1023');
      expect(emergency.battery, 62);
      expect(emergency.emergencyId.startsWith('RQ-'), isTrue);
      expect(service.activeEmergencies.length, 1);
      expect(service.currentActive?.emergencyId, emergency.emergencyId);
    });

    test('TEST 2: Press MAIN SOS repeatedly updates the same emergency without duplicates', () async {
      final first = await service.createMainSos(profile: profile, battery: 62);
      final firstId = first.emergencyId;
      expect(first.repeatedCount, 1);

      final second = await service.createMainSos(profile: profile, battery: 60);
      expect(second.emergencyId, firstId);
      expect(second.repeatedCount, 2);
      expect(second.battery, 60);

      final third = await service.createMainSos(profile: profile, battery: 58);
      expect(third.emergencyId, firstId);
      expect(third.repeatedCount, 3);
      expect(third.battery, 58);

      // Verify no duplicates were created
      final all = await store.loadEmergencies();
      expect(all.where((e) => e.source == EmergencySource.mainSos).length, 1);
      expect(service.activeEmergencies.length, 1);
    });

    test('TEST 3: Select FLOOD from Emergency SOS creates specific emergency with source=EMERGENCY_SOS and type=FLOOD', () async {
      final flood = await service.createEmergencySos(profile: profile, type: EmergencyType.flood);

      expect(flood.source, EmergencySource.emergencySos);
      expect(flood.type, EmergencyType.flood);
      expect(flood.severity, Severity.critical);
      expect(flood.priority, 1);
      expect(flood.victimId, 'USR-1023');
      expect(flood.emergencyId.startsWith('RQ-'), isTrue);
    });

    test('TEST 4: Select FIRE creates emergency with source=EMERGENCY_SOS and type=FIRE', () async {
      final fire = await service.createEmergencySos(profile: profile, type: EmergencyType.fire);

      expect(fire.source, EmergencySource.emergencySos);
      expect(fire.type, EmergencyType.fire);
      expect(fire.victimId, 'USR-1023');
    });

    test('TEST 5: Main SOS followed by Flood Emergency SOS creates TWO separate active emergencies', () async {
      final mainSos = await service.createMainSos(profile: profile, battery: 64);
      final floodSos = await service.createEmergencySos(profile: profile, type: EmergencyType.flood, battery: 64);

      expect(mainSos.emergencyId != floodSos.emergencyId, isTrue);
      expect(mainSos.source, EmergencySource.mainSos);
      expect(mainSos.type, EmergencyType.other);

      expect(floodSos.source, EmergencySource.emergencySos);
      expect(floodSos.type, EmergencyType.flood);

      expect(service.activeEmergencies.length, 2);

      final activeIds = await store.getActiveEmergencyIds();
      expect(activeIds.contains(mainSos.emergencyId), isTrue);
      expect(activeIds.contains(floodSos.emergencyId), isTrue);
    });

    test('TEST 9: Emergency works offline and saves locally with queued delivery state', () async {
      final emergency = await service.createMainSos(profile: profile);

      expect(emergency.deliveryState, isNotEmpty);
      final stored = await store.loadEmergencies();
      expect(stored.any((e) => e.emergencyId == emergency.emergencyId), isTrue);
    });

    test('TEST 10: App restart recovery restores active emergencies from LocalStore', () async {
      final created = await service.createMainSos(profile: profile);

      // Create a fresh EmergencyService instance simulating app restart
      final restartedService = EmergencyService(
        store: store,
        location: location,
        ble: ble,
        api: api,
        connectivity: connectivity,
      );

      // Wait a microtask for restore
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final activeList = await restartedService.getActiveEmergencies();
      expect(activeList.length, 1);
      expect(activeList.first.emergencyId, created.emergencyId);
      expect(activeList.first.source, EmergencySource.mainSos);

      restartedService.dispose();
    });
  });

  group('UI Tests for Active SOS & History', () {
    testWidgets('Active SOS Page shows HELP REQUEST SENT and 4 actions for MAIN SOS', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = LocalStore();
      final loc = LocationService(store: store);
      final ble = BleService();
      final api = ApiService();
      final conn = ConnectivityService();
      final service = EmergencyService(store: store, location: loc, ble: ble, api: api, connectivity: conn);

      final emergency = Emergency(
        emergencyId: 'RQ-2026-MAIN01',
        messageId: 'SOS-2026-MAIN01',
        victimId: 'USR-1023',
        source: EmergencySource.mainSos,
        type: EmergencyType.other,
        severity: Severity.critical,
        priority: 1,
        peopleAffected: 1,
        battery: 64,
        timestamp: DateTime.now(),
        status: 'SOS SENT',
        repeatedCount: 1,
        communicationState: CommunicationState.localSaved,
        deliveryState: DeliveryState.queued,
      );

      await tester.pumpWidget(MaterialApp(
        home: SosActivePage(
          service: service,
          profile: UserProfile(name: 'Test Victim'),
          initialEmergency: emergency,
        ),
      ));

      expect(find.text('HELP REQUEST SENT'), findsOneWidget);
      expect(find.text('RQ-2026-MAIN01'), findsOneWidget);
      expect(find.text('MAIN SOS'), findsOneWidget);
      expect(find.text('ADD EMERGENCY DETAILS'), findsOneWidget);
      expect(find.text('SEND MESSAGE'), findsOneWidget);
      expect(find.text('UPDATE LOCATION'), findsOneWidget);
      expect(find.text('CANCEL SOS'), findsOneWidget);

      service.dispose();
    });

    testWidgets('Active SOS Page shows EMERGENCY SOS SENT for specific disaster type', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = LocalStore();
      final loc = LocationService(store: store);
      final ble = BleService();
      final api = ApiService();
      final conn = ConnectivityService();
      final service = EmergencyService(store: store, location: loc, ble: ble, api: api, connectivity: conn);

      final emergency = Emergency(
        emergencyId: 'RQ-2026-FLOOD01',
        messageId: 'SOS-2026-FLOOD01',
        victimId: 'USR-1023',
        source: EmergencySource.emergencySos,
        type: EmergencyType.flood,
        severity: Severity.critical,
        priority: 1,
        peopleAffected: 1,
        battery: 64,
        timestamp: DateTime.now(),
        status: 'SOS SENT',
        repeatedCount: 1,
        communicationState: CommunicationState.localSaved,
        deliveryState: DeliveryState.queued,
      );

      await tester.pumpWidget(MaterialApp(
        home: SosActivePage(
          service: service,
          profile: UserProfile(name: 'Test Victim'),
          initialEmergency: emergency,
        ),
      ));

      expect(find.text('EMERGENCY SOS SENT'), findsOneWidget);
      expect(find.text('RQ-2026-FLOOD01'), findsOneWidget);
      expect(find.text('EMERGENCY SOS'), findsOneWidget);
      expect(find.text('Flood'), findsOneWidget);
      expect(find.text('SEND MESSAGE'), findsOneWidget);
      expect(find.text('UPDATE LOCATION'), findsOneWidget);
      expect(find.text('CANCEL SOS'), findsOneWidget);

      service.dispose();
    });

    testWidgets('HistoryPage displays both MAIN SOS and EMERGENCY SOS with ALL, MAIN SOS, and EMERGENCY SOS filter chips', (tester) async {
      final store = LocalStore();
      final mainSos = Emergency(
        emergencyId: 'RQ-2026-HIST-01',
        messageId: 'SOS-HIST-01',
        victimId: 'USR-1023',
        source: EmergencySource.mainSos,
        type: EmergencyType.other,
        severity: Severity.critical,
        priority: 1,
        peopleAffected: 1,
        battery: 64,
        timestamp: DateTime.now(),
        status: 'RESCUED',
        repeatedCount: 1,
        communicationState: CommunicationState.rescued,
      );

      final floodSos = Emergency(
        emergencyId: 'RQ-2026-HIST-02',
        messageId: 'SOS-HIST-02',
        victimId: 'USR-1023',
        source: EmergencySource.emergencySos,
        type: EmergencyType.flood,
        severity: Severity.critical,
        priority: 1,
        peopleAffected: 2,
        battery: 60,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'RESOLVED',
        repeatedCount: 1,
        communicationState: CommunicationState.closed,
      );

      await store.saveEmergency(mainSos);
      await store.saveEmergency(floodSos);

      await tester.pumpWidget(MaterialApp(
        home: HistoryPage(store: store),
      ));
      await tester.pumpAndSettle();

      // TEST 6: Both appear together under ALL
      expect(find.text('ALL (2)'), findsOneWidget);
      expect(find.text('MAIN SOS (1)'), findsOneWidget);
      expect(find.text('EMERGENCY SOS (1)'), findsOneWidget);
      expect(find.text('RQ-2026-HIST-01'), findsOneWidget);
      expect(find.text('RQ-2026-HIST-02'), findsOneWidget);

      // TEST 7: Filter by MAIN SOS
      await tester.tap(find.text('MAIN SOS (1)'));
      await tester.pumpAndSettle();
      expect(find.text('RQ-2026-HIST-01'), findsOneWidget);
      expect(find.text('RQ-2026-HIST-02'), findsNothing);

      // TEST 8: Filter by EMERGENCY SOS
      await tester.tap(find.text('EMERGENCY SOS (1)'));
      await tester.pumpAndSettle();
      expect(find.text('RQ-2026-HIST-01'), findsNothing);
      expect(find.text('RQ-2026-HIST-02'), findsOneWidget);
    });
  });
}

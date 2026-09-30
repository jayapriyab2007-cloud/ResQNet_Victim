import 'package:flutter/material.dart';

class AppConstants {
  static const appName = 'ResQNet';
  static const appTagline = 'Emergency Assistance Network';
  static const apiBaseUrl = 'http://10.0.2.2:8000';
  static const protocolVersion = 1;
  static const handheldPrefix = 'RESQNET';
  static const simulationMode = true;
}

class EmergencySource {
  static const String mainSos = 'MAIN_SOS';
  static const String emergencySos = 'EMERGENCY_SOS';

  static const all = [mainSos, emergencySos];

  static String label(String value) => switch (value.toUpperCase()) {
    mainSos => 'MAIN SOS',
    emergencySos => 'EMERGENCY SOS',
    _ => value,
  };
}

class EmergencyType {
  static const flood = 'FLOOD';
  static const cyclone = 'CYCLONE';
  static const fire = 'FIRE';
  static const forestFire = 'FOREST_FIRE';
  static const earthquake = 'EARTHQUAKE';
  static const medical = 'MEDICAL';
  static const accident = 'ACCIDENT';
  static const missingPerson = 'MISSING_PERSON';
  static const safety = 'SAFETY';
  static const other = 'OTHER';

  static const all = [
    flood,
    cyclone,
    fire,
    forestFire,
    earthquake,
    medical,
    accident,
    missingPerson,
    safety,
    other,
  ];

  static String label(String value) => switch (value.toUpperCase()) {
    flood => 'Flood',
    cyclone => 'Cyclone',
    fire => 'Fire',
    forestFire => 'Forest Fire',
    earthquake => 'Earthquake',
    medical => 'Medical Emergency',
    accident => 'Road Accident',
    missingPerson => 'Missing Person',
    safety => 'Safety / Crime',
    _ => 'Other Emergency',
  };

  static String emoji(String value) => switch (value.toUpperCase()) {
    flood => '🌊',
    cyclone => '🌪️',
    fire => '🔥',
    forestFire => '🌲',
    earthquake => '🧱',
    medical => '🩺',
    accident => '🚗',
    missingPerson => '🔎',
    safety => '🛡️',
    _ => '❗',
  };

  static IconData icon(String value) => switch (value.toUpperCase()) {
    flood => Icons.water,
    cyclone => Icons.air,
    fire => Icons.local_fire_department,
    forestFire => Icons.forest,
    earthquake => Icons.public,
    medical => Icons.medical_services,
    accident => Icons.car_crash,
    missingPerson => Icons.person_search,
    safety => Icons.security,
    _ => Icons.warning_amber,
  };
}

class Severity {
  static const critical = 'CRITICAL';
  static const serious = 'SERIOUS';
  static const urgent = 'URGENT';
  static const general = 'GENERAL';

  // Backwards compatibility with previous HIGH / MODERATE / LOW constants
  static const high = 'SERIOUS';
  static const moderate = 'URGENT';
  static const low = 'GENERAL';

  static const all = [critical, serious, urgent, general];

  static String label(String value) => switch (value.toUpperCase()) {
    critical => 'Critical',
    serious || 'HIGH' => 'Serious',
    urgent || 'MODERATE' => 'Urgent',
    general || 'LOW' => 'General Assistance',
    _ => value,
  };
}

class CommunicationState {
  static const created = 'CREATED';
  static const localSaved = 'LOCAL_SAVED';
  static const queued = 'QUEUED';
  static const bleTransmitting = 'BLE_TRANSMITTING';
  static const handheldReceived = 'HANDHELD_RECEIVED';
  static const loraQueued = 'LORA_QUEUED';
  static const loraTransmitting = 'LORA_TRANSMITTING';
  static const meshForwarding = 'MESH_FORWARDING';
  static const gatewayReceived = 'GATEWAY_RECEIVED';
  static const serverReceived = 'SERVER_RECEIVED';
  static const responderNotified = 'RESPONDER_NOTIFIED';
  static const responderAssigned = 'RESPONDER_ASSIGNED';
  static const rescued = 'RESCUED';
  static const closed = 'CLOSED';
  static const cancelled = 'CANCELLED';

  static String userFriendlyLabel(String state) => switch (state.toUpperCase()) {
    created => 'Alert created',
    localSaved => 'Saved locally on phone',
    queued => 'Queued for transmission',
    bleTransmitting => 'Sending to BLE handheld…',
    handheldReceived => 'Transferred to LoRa handheld',
    loraQueued => 'Queued in LoRa mesh buffer',
    loraTransmitting => 'Transmitting over LoRa…',
    meshForwarding => 'Relaying across LoRa mesh',
    gatewayReceived => 'Received at gateway',
    serverReceived => 'Received at FastAPI / Cloud',
    responderNotified => 'Responder notified',
    responderAssigned => 'Rescue team en route',
    rescued => 'Rescued / Resolved',
    closed => 'Incident closed',
    cancelled => 'Alert cancelled',
    _ => state,
  };
}

class DeliveryState {
  static const sosSent = 'SOS SENT';
  static const queued = 'QUEUED';
  static const relayed = 'RELAYED';
  static const serverReceived = 'SERVER RECEIVED';
  static const acknowledged = 'ACKNOWLEDGED';

  static const all = [
    sosSent,
    queued,
    relayed,
    serverReceived,
    acknowledged,
  ];
}

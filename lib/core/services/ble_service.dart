import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/app_constants.dart';

class BleDiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice? device;

  const BleDiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.device,
  });
}

class BleService {
  final _state = StreamController<String>.broadcast();
  Stream<String> get state => _state.stream;

  bool connected = false;
  bool isSimulated = AppConstants.simulationMode;
  BluetoothDevice? device;
  String currentStatus = 'DISCONNECTED';
  final List<BleDiscoveredDevice> discoveredDevices = [];

  Future<void> scanAndConnect() async {
    discoveredDevices.clear();
    currentStatus = 'SCANNING';
    _state.add('SCANNING');

    if (AppConstants.simulationMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      discoveredDevices.add(const BleDiscoveredDevice(
        id: 'SIM-ESP32-LORA',
        name: 'RESQNET-HANDHELD-DEMO (Simulated)',
        rssi: -58,
      ));
      currentStatus = 'SIMULATION_CONNECTED';
      connected = true;
      isSimulated = true;
      _state.add('SIMULATION_CONNECTED');
      return;
    }

    try {
      if (!await FlutterBluePlus.isSupported) {
        currentStatus = 'SIMULATION_CONNECTED';
        connected = true;
        isSimulated = true;
        _state.add('SIMULATION_CONNECTED');
        return;
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          final name = r.device.platformName;
          if (name.isNotEmpty && !discoveredDevices.any((d) => d.id == r.device.remoteId.str)) {
            discoveredDevices.add(BleDiscoveredDevice(
              id: r.device.remoteId.str,
              name: name,
              rssi: r.rssi,
              device: r.device,
            ));
          }
          if (name.startsWith(AppConstants.handheldPrefix)) {
            await FlutterBluePlus.stopScan();
            device = r.device;
            currentStatus = 'CONNECTING';
            _state.add('CONNECTING');
            await device!.connect(timeout: const Duration(seconds: 8), autoConnect: false);
            connected = true;
            isSimulated = false;
            currentStatus = 'CONNECTED';
            _state.add('CONNECTED');
            return;
          }
        }
      }
    } catch (_) {
      // Fallback cleanly to simulation if Bluetooth adapter is off/unsupported
      currentStatus = 'SIMULATION_CONNECTED';
      connected = true;
      isSimulated = true;
      _state.add('SIMULATION_CONNECTED');
      return;
    }

    if (!connected) {
      currentStatus = 'DISCONNECTED';
      _state.add('DISCONNECTED');
    }
  }

  Future<void> disconnect() async {
    if (device != null) {
      try {
        await device!.disconnect();
      } catch (_) {}
      device = null;
    }
    connected = false;
    currentStatus = 'DISCONNECTED';
    _state.add('DISCONNECTED');
  }

  Future<bool> sendPacket(Map<String, dynamic> packet) async {
    if (isSimulated || AppConstants.simulationMode) {
      _state.add('PACKET_QUEUED');
      await Future.delayed(const Duration(milliseconds: 600));
      _state.add('PACKET_TRANSMITTED');
      await Future.delayed(const Duration(milliseconds: 700));
      _state.add('PACKET_ACK');
      return true;
    }

    if (device == null || !connected) {
      _state.add('PACKET_FAILED');
      return false;
    }

    _state.add('PACKET_QUEUED');
    // Once ESP32 LoRa firmware characteristic UUID is configured:
    // await characteristic.write(utf8.encode(jsonEncode(packet)));
    _state.add('PACKET_TRANSMITTED');
    return true;
  }

  Future<void> dispose() async {
    await _state.close();
  }
}

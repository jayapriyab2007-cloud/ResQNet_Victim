const express = require('express');
const router = express.Router();
const os = require('os');

const Emergency = require('../models/Emergency');
const AuditLog = require('../models/AuditLog');
const Notification = require('../models/Notification');
const socketService = require('../services/socketService');
const { getAssignedTeam, calculatePriority } = require('../utils/routing');

// Track gateway stats in-memory
const gatewayStats = {
  packetsReceived: 0,
  lastPacketAt: null,
  lastNodeId: null,
  activeNodes: new Set()
};

/**
 * Helper to get local IPv4 addresses for ESP32 configuration guidance
 */
function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const ifaceName of Object.keys(interfaces)) {
    for (const iface of interfaces[ifaceName]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ interface: ifaceName, ip: iface.address });
      }
    }
  }
  return addresses;
}

/**
 * Generate unique LoRa emergency ID
 */
function generateLoraId() {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomHex = Math.random().toString(36).substring(2, 7).toUpperCase();
  return `RQ-LORA-${dateStr}-${randomHex}`;
}

/**
 * POST /api/lora/message
 * Ingestion endpoint for ESP32 LoRa Gateway
 * Accepts JSON or compact raw packet string
 */
router.post('/message', async (req, res) => {
  try {
    let payload = req.body;

    // Handle plain text payload if body parser passed string or raw text
    if (typeof payload === 'string') {
      try {
        payload = JSON.parse(payload);
      } catch (e) {
        // Parse delimiter formatted string (e.g., "NODE_01;Flood;Critical;12.8342;79.7036;2;Trapped;RSSI=-80")
        const parts = payload.split(/;|\||,/);
        payload = {
          sender_id: parts[0] || 'LORA-NODE',
          emergency_type: parts[1] || 'Flood',
          severity: parts[2] || 'Critical',
          latitude: parseFloat(parts[3]) || 12.8342,
          longitude: parseFloat(parts[4]) || 79.7036,
          people_affected: parseInt(parts[5], 10) || 1,
          message: parts[6] || 'SOS rescue broadcast received over LoRa radio',
          rssi: -80
        };
      }
    }

    const sender_id = (payload.sender_id || payload.node_id || payload.nodeId || 'LORA_NODE_' + Math.floor(100 + Math.random() * 900)).toString().trim();
    const message = (payload.message || payload.msg || payload.text || 'Emergency SOS received via ESP32 LoRa mesh radio').toString().trim();
    const emergency_type = (payload.emergency_type || payload.type || 'Flood').toString().trim();
    const severity = (payload.severity || payload.sev || 'Critical').toString().trim();
    const people_affected = Math.max(1, parseInt(payload.people_affected || payload.people || 1, 10));

    // Geographical coordinates with default fallback if node has no GPS module
    let latitude = parseFloat(payload.latitude || payload.lat);
    let longitude = parseFloat(payload.longitude || payload.lng || payload.lon);

    let location_source = 'LORA';
    if (isNaN(latitude) || isNaN(longitude) || latitude === 0 || longitude === 0) {
      // Default to central command deployment zone if GPS is absent on LoRa node
      latitude = 12.8342;
      longitude = 79.7036;
      location_source = 'LORA_GATEWAY_FIX';
    }

    const rssi = typeof payload.rssi === 'number' ? payload.rssi : (payload.rssi ? parseFloat(payload.rssi) : -75);
    const snr = typeof payload.snr === 'number' ? payload.snr : (payload.snr ? parseFloat(payload.snr) : 9.0);
    const battery_level = payload.battery_level || payload.battery || null;
    const frequency = payload.frequency || '433.0 MHz / 868.0 MHz';

    // Update gateway telemetry stats
    gatewayStats.packetsReceived += 1;
    gatewayStats.lastPacketAt = new Date();
    gatewayStats.lastNodeId = sender_id;
    gatewayStats.activeNodes.add(sender_id);

    const emergency_id = generateLoraId();
    const priority = calculatePriority(severity);
    const assignedTeam = getAssignedTeam(emergency_type);

    const newEmergency = new Emergency({
      emergency_id,
      user_id: sender_id,
      emergency_type,
      severity,
      priority,
      people_affected,
      message,
      latitude,
      longitude,
      location_source,
      source: 'LORA',
      assigned_team: assignedTeam,
      status: 'SOS_CREATED',
      assigned_responders: [],
      lora_metadata: {
        rssi,
        snr,
        node_id: sender_id,
        battery_level: battery_level ? Number(battery_level) : null,
        frequency,
        gateway_id: payload.gateway_id || 'ESP32_BASE_GATEWAY',
        raw_packet: typeof payload === 'object' ? JSON.stringify(payload) : String(payload),
        received_at: new Date()
      },
      created_at: new Date(),
      updated_at: new Date()
    });

    await newEmergency.save();

    // Broadcast in real-time to all connected Admin & Responder terminals
    socketService.broadcastNewEmergency(newEmergency);

    // Create system notification
    const notif = await Notification.create({
      target_role: 'ADMIN',
      type: 'LORA_RESCUE_SIGNAL',
      title: `📡 LoRa Rescue Signal Received: ${emergency_id}`,
      message: `Node ${sender_id}: "${message}" | Signal: ${rssi} dBm (SNR ${snr} dB)`,
      emergency_id,
      priority
    }).catch(() => null);

    if (notif) {
      socketService.emitNotification(notif);
    }

    // Audit Log
    await AuditLog.create({
      user_id: sender_id,
      user_name: `LoRa Node ${sender_id}`,
      role: 'LORA_GATEWAY',
      action: 'LORA_PACKET_RECEIVED',
      emergency_id,
      metadata: { rssi, snr, frequency, emergency_type, location_source }
    }).catch(() => {});

    console.log(`📡 [LoRa Gateway] Emergency received from ${sender_id}: "${message}" (RSSI: ${rssi} dBm, ID: ${emergency_id})`);

    return res.status(201).json({
      success: true,
      message: 'LoRa rescue emergency message processed successfully',
      emergency_id,
      emergency: newEmergency,
      telemetry: {
        rssi,
        snr,
        gateway_packets_total: gatewayStats.packetsReceived
      }
    });
  } catch (err) {
    console.error('LoRa ingestion error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to process LoRa emergency message',
      error: err.message
    });
  }
});

// Alias endpoint for convenience
router.post('/packet', (req, res, next) => {
  req.url = '/message';
  router.handle(req, res, next);
});

/**
 * GET /api/lora/status
 * Gateway telemetry & IP configuration guide
 */
router.get('/status', (req, res) => {
  const localIps = getLocalIpAddresses();
  const primaryIp = localIps.find(i => i.ip.startsWith('192.168.') || i.ip.startsWith('172.')) || localIps[0] || { ip: 'localhost' };

  return res.status(200).json({
    success: true,
    status: 'ONLINE',
    service: 'ResQNet ESP32 LoRa Receiver Gateway',
    packets_received: gatewayStats.packetsReceived,
    last_packet_at: gatewayStats.lastPacketAt,
    last_node_id: gatewayStats.lastNodeId,
    active_nodes_count: gatewayStats.activeNodes.size,
    server_ips: localIps,
    esp32_target_url: `http://${primaryIp.ip}:5000/api/lora/message`,
    frequency_bands: ['433 MHz', '868 MHz', '915 MHz'],
    supported_protocols: ['HTTP POST (WiFi Gateway)', 'USB Serial COM Bridge']
  });
});

/**
 * GET /api/lora/history
 * List recent emergencies received via LoRa radio
 */
router.get('/history', async (req, res) => {
  try {
    const loraEmergencies = await Emergency.find({
      $or: [
        { source: 'LORA' },
        { location_source: { $regex: /^LORA/i } }
      ]
    }).sort({ created_at: -1 }).limit(50);

    return res.status(200).json({
      success: true,
      count: loraEmergencies.length,
      emergencies: loraEmergencies
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Failed to retrieve LoRa emergencies' });
  }
});

/**
 * POST /api/lora/simulate
 * Test simulation endpoint for developers and demo testing
 */
router.post('/simulate', async (req, res) => {
  try {
    const sampleNodes = ['LORA-NODE-ALPHA', 'LORA-NODE-BRAVO', 'LORA-NODE-CHARLIE', 'LORA-NODE-DELTA'];
    const sampleMessages = [
      'Flood waters rising rapidly on ground floor. 3 people trapped, elderly person needs evacuation!',
      'Severe building collapse tremor felt. Need rescue team with stretcher and first aid.',
      'Fire spreading to residential quarters. Workers assembled at emergency muster point.',
      'Flash flood warning. Water current too strong to cross. 4 family members stranded on roof.'
    ];
    const sampleTypes = ['Flood', 'Structural Collapse', 'Fire', 'Flood'];

    const idx = Math.floor(Math.random() * sampleNodes.length);
    const simPayload = {
      sender_id: req.body.sender_id || sampleNodes[idx],
      message: req.body.message || sampleMessages[idx],
      emergency_type: req.body.emergency_type || sampleTypes[idx],
      severity: req.body.severity || 'Critical',
      people_affected: req.body.people_affected || Math.floor(1 + Math.random() * 5),
      latitude: req.body.latitude || (12.8340 + (Math.random() - 0.5) * 0.05),
      longitude: req.body.longitude || (79.7030 + (Math.random() - 0.5) * 0.05),
      rssi: req.body.rssi || Math.floor(-95 + Math.random() * 30),
      snr: req.body.snr || parseFloat((6 + Math.random() * 5).toFixed(1)),
      battery_level: req.body.battery_level || Math.floor(70 + Math.random() * 30)
    };

    req.body = simPayload;
    return router.handle({ ...req, url: '/message' }, res);
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Simulation failed', error: err.message });
  }
});

module.exports = router;

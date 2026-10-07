const express = require('express');
const router = express.Router();
const Emergency = require('../models/Emergency');
const AuditLog = require('../models/AuditLog');
const Notification = require('../models/Notification');
const socketService = require('../services/socketService');
const { getAssignedTeam, calculatePriority, generateEmergencyId } = require('../utils/routing');

/**
 * POST /api/emergencies or /api/emergency
 * Create a new emergency SOS request.
 * Includes Idempotency Check using emergency_id to protect against duplicate retries during poor connectivity.
 */
router.post('/', async (req, res) => {
  try {
    const {
      user_id,
      emergency_type,
      severity,
      people_affected,
      message,
      latitude,
      longitude,
      location_source,
      emergency_id
    } = req.body;

    // Idempotency protection for offline / poor connection retries
    if (emergency_id) {
      const existing = await Emergency.findOne({ emergency_id });
      if (existing) {
        console.log(`[EMERGENCY] Idempotent replay recognized: ${emergency_id}`);
        return res.status(200).json({
          success: true,
          message: 'Emergency request already processed',
          emergency: existing
        });
      }
    }

    if (!user_id || typeof user_id !== 'string' || !user_id.trim()) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    if (!emergency_type || typeof emergency_type !== 'string' || !emergency_type.trim()) {
      return res.status(400).json({ error: 'emergency_type is required' });
    }

    if (!severity || typeof severity !== 'string' || !severity.trim()) {
      return res.status(400).json({ error: 'severity is required' });
    }

    if (latitude === undefined || latitude === null || typeof latitude !== 'number' || isNaN(latitude)) {
      return res.status(400).json({ error: 'latitude must be a valid number' });
    }

    if (longitude === undefined || longitude === null || typeof longitude !== 'number' || isNaN(longitude)) {
      return res.status(400).json({ error: 'longitude must be a valid number' });
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ error: 'Coordinates are out of geographical range' });
    }

    const assignedTeam = getAssignedTeam(emergency_type);
    const priority = calculatePriority(severity);
    const resolvedEmergencyId = emergency_id || generateEmergencyId();

    const normalizedSource = (location_source || 'GPS').toUpperCase() === 'MANUAL' ? 'MANUAL' : 'GPS';

    const newEmergency = new Emergency({
      emergency_id: resolvedEmergencyId,
      user_id: user_id.trim(),
      emergency_type: emergency_type.trim(),
      severity: severity.trim(),
      priority: priority,
      people_affected: Number(people_affected) > 0 ? Number(people_affected) : 1,
      message: message ? message.trim() : 'Immediate SOS triggered by victim',
      latitude: latitude,
      longitude: longitude,
      location_source: normalizedSource,
      assigned_team: assignedTeam,
      status: 'SOS_CREATED',
      assigned_responders: [],
      created_at: new Date(),
      updated_at: new Date()
    });

    await newEmergency.save();

    // Audit log
    await AuditLog.create({
      user_id: user_id.trim(),
      role: 'VICTIM',
      action: 'VICTIM_CREATED_SOS',
      emergency_id: newEmergency.emergency_id,
      metadata: {
        emergency_type: newEmergency.emergency_type,
        priority: newEmergency.priority,
        latitude: newEmergency.latitude,
        longitude: newEmergency.longitude
      }
    }).catch(() => {});

    // Broadcast real-time Socket.IO event to all admins and responders
    socketService.broadcastNewEmergency(newEmergency);

    console.log(`[EMERGENCY] SOS Created: ${newEmergency.emergency_id} | Type: ${newEmergency.emergency_type} | Priority: ${newEmergency.priority} | Team: ${newEmergency.assigned_team}`);

    return res.status(201).json({
      success: true,
      message: 'Emergency request received',
      emergency: newEmergency
    });
  } catch (err) {
    console.error('Create Emergency Error:', err);
    return res.status(500).json({ error: 'Failed to record emergency.' });
  }
});

/**
 * GET /api/emergencies/user/:user_id
 * Retrieve emergency history for a victim.
 */
router.get('/user/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    const emergencies = await Emergency.find({ user_id: user_id.trim() }).sort({ created_at: -1 });
    return res.status(200).json({
      success: true,
      count: emergencies.length,
      emergencies
    });
  } catch (err) {
    console.error('Error fetching victim emergencies:', err);
    return res.status(500).json({ error: 'Failed to retrieve emergency records.' });
  }
});

/**
 * PATCH /api/emergencies/:emergency_id/cancel
 * Cancel an emergency.
 */
router.patch('/:emergency_id/cancel', async (req, res) => {
  try {
    const { emergency_id } = req.params;
    const emergency = await Emergency.findOneAndUpdate(
      { emergency_id },
      { status: 'Cancelled', updated_at: new Date() },
      { new: true }
    );
    if (!emergency) {
      return res.status(404).json({ error: 'Emergency record not found' });
    }

    socketService.broadcastEmergencyStatusChanged({
      emergency_id: emergency.emergency_id,
      status: 'Cancelled',
      updated_at: emergency.updated_at
    });

    return res.status(200).json({
      success: true,
      message: 'Emergency request cancelled successfully',
      emergency
    });
  } catch (err) {
    console.error('Error cancelling emergency:', err);
    return res.status(500).json({ error: 'Failed to cancel emergency.' });
  }
});

/**
 * GET /api/emergencies/:id
 * Retrieve single emergency details.
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const emergency = await Emergency.findOne({
      $or: [{ emergency_id: id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }]
    });

    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    return res.json({ success: true, emergency });
  } catch (err) {
    console.error('Get emergency detail error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

/**
 * POST /api/emergencies/:id/chat
 * Send a message for an emergency.
 */
router.post('/:id/chat', async (req, res) => {
  try {
    const { id } = req.params;
    const { sender_id, sender_role, message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message content is required' });
    }

    const emergency = await Emergency.findOne({
      $or: [{ emergency_id: id }, { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }]
    });

    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    const chatMsg = {
      sender_id: sender_id || 'system',
      sender_role: sender_role || 'VICTIM',
      message: message.trim(),
      created_at: new Date(),
      delivery_status: 'DELIVERED'
    };

    emergency.chat_messages.push(chatMsg);
    await emergency.save();

    socketService.broadcastMessage({
      emergency_id: emergency.emergency_id,
      message: chatMsg
    });

    return res.json({ success: true, chatMessage: chatMsg });
  } catch (err) {
    console.error('Send chat message error:', err);
    return res.status(500).json({ success: false, message: 'Failed to send message' });
  }
});

module.exports = router;

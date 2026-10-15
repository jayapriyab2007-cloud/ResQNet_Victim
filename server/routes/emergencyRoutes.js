const mongoose = require('mongoose');
const express = require('express');
const router = express.Router();
const Emergency = require('../models/Emergency');
const User = require('../models/User');
const AuditLog = require('../models/AuditLog');
const Notification = require('../models/Notification');
const socketService = require('../services/socketService');
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../middleware/auth');
const { getAssignedTeam, calculatePriority, generateEmergencyId } = require('../utils/routing');

/**
 * POST /api/emergencies or /api/emergency
 * Create a new emergency SOS request.
 * - Supports verified JWT token or authenticated user_id from request body/headers
 * - Validates required fields: user_id, emergency_type, severity, coordinates
 * - Includes Idempotency Check using emergency_id
 * - Enforces neutral SOS event without speculative narratives
 * - Supports explicit MANUAL location source when GPS is unavailable
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
      location_accuracy,
      location_timestamp,
      location_source,
      location_name,
      emergency_id
    } = req.body;

    // 1. Idempotency protection for offline / poor connection retries
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

    // 2. Authentication & User Identity (supports JWT token or explicit user_id)
    let authenticatedUser = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        authenticatedUser = jwt.verify(token, JWT_SECRET);
      } catch (tokenErr) {
        return res.status(401).json({
          error: 'Unauthorized: Invalid or expired authentication token'
        });
      }
    }

    const effectiveUserId =
      (authenticatedUser && (authenticatedUser.id || authenticatedUser._id)) ||
      (typeof user_id === 'string' && user_id.trim()) ||
      (req.headers['x-user-id'] && req.headers['x-user-id'].trim()) ||
      null;

    if (!effectiveUserId) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    // 3. Validate emergency_type
    if (!emergency_type || typeof emergency_type !== 'string' || !emergency_type.trim()) {
      return res.status(400).json({ error: 'emergency_type is required' });
    }
    const resolvedType = emergency_type.trim();

    // 4. Validate severity
    const resolvedSeverity = (typeof severity === 'string' && severity.trim())
      ? severity.trim()
      : 'Critical';

    // 5. Coordinate validation & handling
    const isManualOrNone = (location_source && ['MANUAL', 'NONE'].includes(String(location_source).toUpperCase())) || Boolean(location_name);

    let resolvedLat = null;
    let resolvedLng = null;

    if (latitude === undefined || latitude === null || latitude === '') {
      if (!isManualOrNone) {
        return res.status(400).json({ error: 'latitude must be a valid number' });
      }
    } else {
      const parsedLat = Number(latitude);
      if (isNaN(parsedLat)) {
        return res.status(400).json({ error: 'latitude must be a valid number' });
      }
      if (parsedLat < -90 || parsedLat > 90) {
        return res.status(400).json({ error: 'Coordinates are out of geographical range' });
      }
      resolvedLat = parsedLat;
    }

    if (longitude === undefined || longitude === null || longitude === '') {
      if (!isManualOrNone) {
        return res.status(400).json({ error: 'longitude must be a valid number' });
      }
    } else {
      const parsedLng = Number(longitude);
      if (isNaN(parsedLng)) {
        return res.status(400).json({ error: 'longitude must be a valid number' });
      }
      if (parsedLng < -180 || parsedLng > 180) {
        return res.status(400).json({ error: 'Coordinates are out of geographical range' });
      }
      resolvedLng = parsedLng;
    }

    // Determine honest location source
    let resolvedSource = 'GPS';
    if (resolvedLat !== null && resolvedLng !== null) {
      resolvedSource = (location_source || 'GPS').toUpperCase() === 'MANUAL' ? 'MANUAL' : 'GPS';
    } else {
      resolvedSource = (location_source || '').toUpperCase() === 'MANUAL' || location_name ? 'MANUAL' : 'NONE';
    }

    // Fetch user details from database if available (non-blocking)
    let trustedVictimName = (authenticatedUser && authenticatedUser.name) || req.body.victim_name || req.body.name || '';
    let trustedVictimPhone = req.body.victim_phone || req.body.phone || '';
    let trustedVictimBloodGroup = req.body.victim_blood_group || req.body.blood_group || '';
    let trustedVictimEmergencyContact = req.body.victim_emergency_contact || req.body.emergency_contact || '';

    try {
      if (mongoose.connection && mongoose.connection.readyState === 1) {
        const userDoc = await User.findById(effectiveUserId);
        if (userDoc) {
          trustedVictimName = userDoc.name || trustedVictimName;
          trustedVictimPhone = userDoc.phone || trustedVictimPhone;
          trustedVictimBloodGroup = userDoc.blood_group || trustedVictimBloodGroup;
          trustedVictimEmergencyContact = userDoc.emergency_contact || trustedVictimEmergencyContact;
        }
      }
    } catch (e) {
      // Safe fallback if not found or non-ObjectId format
    }

    const priority = calculatePriority(resolvedSeverity);
    const resolvedEmergencyId = emergency_id || generateEmergencyId();
    const assignedTeam = getAssignedTeam(resolvedType);

    // Optional incident description remains empty string until explicitly supplied by victim
    const validatedMessage = (typeof message === 'string' && message.trim())
      ? message.trim()
      : '';

    const resolvedAccuracy = (typeof location_accuracy === 'number' && !isNaN(location_accuracy))
      ? Math.round(location_accuracy)
      : null;

    const resolvedLocationTimestamp = location_timestamp ? new Date(location_timestamp) : null;
    const resolvedLocationName = (typeof location_name === 'string' && location_name.trim())
      ? location_name.trim()
      : '';

    const newEmergency = new Emergency({
      emergency_id: resolvedEmergencyId,
      user_id: effectiveUserId,
      victim_name: trustedVictimName,
      victim_phone: trustedVictimPhone,
      victim_blood_group: trustedVictimBloodGroup,
      victim_emergency_contact: trustedVictimEmergencyContact,
      emergency_type: resolvedType,
      severity: resolvedSeverity,
      priority: priority,
      people_affected: Number(people_affected) > 0 ? Number(people_affected) : 1,
      message: validatedMessage,
      latitude: resolvedLat,
      longitude: resolvedLng,
      location_accuracy: resolvedAccuracy,
      location_timestamp: resolvedLocationTimestamp,
      location_source: resolvedSource,
      location_name: resolvedLocationName,
      assigned_team: assignedTeam,
      status: 'SOS_CREATED',
      assigned_responders: [],
      created_at: new Date(),
      updated_at: new Date()
    });

    await newEmergency.save();

    // Audit log
    await AuditLog.create({
      user_id: effectiveUserId,
      role: 'VICTIM',
      action: 'VICTIM_CREATED_SOS',
      emergency_id: newEmergency.emergency_id,
      metadata: {
        emergency_type: newEmergency.emergency_type,
        priority: newEmergency.priority,
        latitude: newEmergency.latitude,
        longitude: newEmergency.longitude,
        location_source: newEmergency.location_source
      }
    }).catch(() => {});

    // Broadcast real-time Socket.IO event to all admins and responders
    socketService.broadcastNewEmergency(newEmergency);

    console.log(`[EMERGENCY] SOS Created: ${newEmergency.emergency_id} | Type: ${newEmergency.emergency_type} | Team: ${newEmergency.assigned_team} | Loc: ${newEmergency.location_source}`);

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
 * Cancel an active emergency request.
 * Verifies victim ownership or admin authorization.
 * Handles already-cancelled and resolved emergencies safely.
 */
router.patch('/:emergency_id/cancel', async (req, res) => {
  try {
    const { emergency_id } = req.params;

    if (!emergency_id || !emergency_id.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Emergency ID parameter is required'
      });
    }

    const trimmedId = emergency_id.trim();
    const isObjectId = trimmedId.match(/^[0-9a-fA-F]{24}$/);

    // 1. Locate emergency by custom emergency_id or MongoDB _id
    const emergency = await Emergency.findOne({
      $or: [
        { emergency_id: trimmedId },
        { _id: isObjectId ? trimmedId : null }
      ]
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        error: 'Emergency record not found'
      });
    }

    // 2. Identify the requesting user (via JWT token or request body/headers)
    let authenticatedUser = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        authenticatedUser = jwt.verify(token, JWT_SECRET);
        req.user = authenticatedUser;
      } catch (tokenErr) {
        return res.status(401).json({
          success: false,
          error: 'Unauthorized: Invalid or expired authentication token'
        });
      }
    }

    const requestingUserId =
      (authenticatedUser && authenticatedUser.id) ||
      (req.body && req.body.user_id) ||
      req.headers['x-user-id'] ||
      req.query.user_id;

    if (!requestingUserId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Authentication token or user_id is required to cancel this emergency'
      });
    }

    // 3. Ownership Verification: Ensure logged-in victim owns the emergency (or is ADMIN)
    const isAdmin = authenticatedUser && authenticatedUser.role === 'ADMIN';
    const normalizedRequestingId = String(requestingUserId).trim();
    const normalizedOwnerId = String(emergency.user_id).trim();

    if (!isAdmin && normalizedRequestingId !== normalizedOwnerId) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to cancel this emergency. It belongs to another user.'
      });
    }

    // 4. State validation: Safe handling of already-cancelled and resolved states
    const currentStatus = (emergency.status || '').toUpperCase();
    if (currentStatus === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        error: 'Emergency request has already been cancelled',
        emergency
      });
    }

    if (currentStatus === 'RESOLVED') {
      return res.status(400).json({
        success: false,
        error: 'This emergency has already been resolved and cannot be cancelled',
        emergency
      });
    }

    // 5. Apply Cancellation
    const previousStatus = emergency.status;
    emergency.status = 'Cancelled';
    emergency.updated_at = new Date();

    if (req.body && req.body.reason) {
      emergency.notes.push({
        author_id: normalizedRequestingId,
        author_name: authenticatedUser?.name || 'Victim',
        author_role: authenticatedUser?.role || 'VICTIM',
        note: `Cancelled by victim: ${req.body.reason.trim()}`,
        created_at: new Date()
      });
    }

    await emergency.save();

    // 6. Audit Logging
    await AuditLog.create({
      user_id: normalizedRequestingId,
      role: authenticatedUser?.role || 'VICTIM',
      action: 'VICTIM_CANCELLED_SOS',
      emergency_id: emergency.emergency_id,
      metadata: {
        previous_status: previousStatus,
        cancellation_time: emergency.updated_at,
        cancelled_by: normalizedRequestingId
      }
    }).catch(() => {});

    // 7. Real-time Socket.IO Broadcast to all connected clients & dashboards
    socketService.broadcastEmergencyStatusChanged({
      emergency_id: emergency.emergency_id,
      status: 'Cancelled',
      updated_at: emergency.updated_at
    });
    socketService.broadcastEmergencyUpdated(emergency);

    console.log(`[EMERGENCY] SOS Cancelled: ${emergency.emergency_id} by user: ${normalizedRequestingId}`);

    return res.status(200).json({
      success: true,
      message: 'Emergency request cancelled successfully',
      emergency
    });
  } catch (err) {
    console.error('Error cancelling emergency:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to cancel emergency.'
    });
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

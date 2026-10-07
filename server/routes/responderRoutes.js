const express = require('express');
const router = express.Router();

const Emergency = require('../models/Emergency');
const User = require('../models/User');
const Notification = require('../models/Notification');
const AuditLog = require('../models/AuditLog');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  emitEmergencyUpdated,
  emitEmergencyStatusChanged,
  emitResponderLocation,
  emitResponderStatus,
  emitNotification,
  emitChatMessage
} = require('../services/socketService');

// Require authentication and RESPONDER or ADMIN role
router.use(requireAuth);
router.use(requireRole('RESPONDER', 'ADMIN'));

/**
 * @route   GET /api/responder/emergencies
 * @desc    Fetch active and recent emergencies assigned to this responder
 * @access  Responder / Admin
 */
router.get('/emergencies', async (req, res) => {
  try {
    const responderId = req.user.responder_id || req.user.id;
    const responderName = req.user.name;

    const emergencies = await Emergency.find({
      $or: [
        { 'assigned_responders.responder_id': responderId },
        { 'assigned_responders.responder_id': req.user.id },
        { 'assigned_responders.name': responderName }
      ]
    }).sort({ created_at: -1 });

    return res.status(200).json({
      success: true,
      count: emergencies.length,
      emergencies
    });
  } catch (err) {
    console.error('Error fetching responder emergencies:', err);
    return res.status(500).json({ success: false, message: 'Server error retrieving assigned missions' });
  }
});

/**
 * @route   GET /api/responder/emergencies/:id
 * @desc    Fetch specific emergency details for responder
 * @access  Responder / Admin
 */
router.get('/emergencies/:id', async (req, res) => {
  try {
    const emergency = await Emergency.findOne({ emergency_id: req.params.id });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }
    return res.status(200).json({ success: true, emergency });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error retrieving emergency' });
  }
});

/**
 * @route   POST /api/responder/emergencies/:id/accept
 * @desc    Acknowledge / accept assigned mission
 * @access  Responder
 */
router.post('/emergencies/:id/accept', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const responderId = req.user.responder_id || req.user.id;

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    // Update responder status inside assigned_responders
    let found = false;
    emergency.assigned_responders = emergency.assigned_responders.map(r => {
      if (r.responder_id === responderId || r.responder_id === req.user.id || r.name === req.user.name) {
        found = true;
        return {
          ...r.toObject(),
          status: 'Accepted',
          accepted_at: new Date()
        };
      }
      return r;
    });

    if (emergency.status === 'RESPONDER_ASSIGNED') {
      emergency.status = 'RESPONDER_ACCEPTED';
    }
    emergency.updated_at = new Date();
    await emergency.save();

    // Set user availability to BUSY
    await User.findByIdAndUpdate(req.user.id, { availability: 'BUSY' });

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'RESPONDER',
      action: 'RESPONDER_ACCEPTED_ASSIGNMENT',
      emergency_id: emergency.emergency_id
    });

    // Notify victim and admins
    const notif = await Notification.create({
      user_id: emergency.user_id,
      target_role: 'ALL',
      type: 'MISSION_ACCEPTED',
      title: `🟢 Rescue Team Dispatched: ${req.user.name}`,
      message: `${req.user.name} has accepted the rescue mission for incident ${emergency.emergency_id}.`,
      emergency_id: emergency.emergency_id
    });
    emitNotification(notif);

    emitEmergencyStatusChanged(emergency);

    return res.status(200).json({
      success: true,
      message: 'Mission assignment accepted',
      emergency
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error accepting mission' });
  }
});

/**
 * @route   POST /api/responder/emergencies/:id/decline
 * @desc    Decline assignment
 * @access  Responder
 */
router.post('/emergencies/:id/decline', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const responderId = req.user.responder_id || req.user.id;
    const { reason } = req.body;

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    emergency.assigned_responders = emergency.assigned_responders.filter(
      r => r.responder_id !== responderId && r.responder_id !== req.user.id
    );

    if (emergency.assigned_responders.length === 0) {
      emergency.status = 'TEAM_NOTIFIED';
    }
    emergency.updated_at = new Date();
    await emergency.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'RESPONDER',
      action: 'RESPONDER_DECLINED_ASSIGNMENT',
      emergency_id: emergency.emergency_id,
      metadata: { reason }
    });

    emitEmergencyUpdated(emergency);

    return res.status(200).json({
      success: true,
      message: 'Assignment declined',
      emergency
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error declining assignment' });
  }
});

/**
 * @route   PATCH /api/responder/emergencies/:id/status
 * @desc    Progress response status: ON_THE_WAY, ARRIVED, SERVICE_STARTED, RESOLVED
 * @access  Responder / Admin
 */
router.patch('/emergencies/:id/status', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { status, resolution_note } = req.body;

    const allowedStatuses = [
      'RESPONDER_ACCEPTED',
      'ON_THE_WAY',
      'ARRIVED',
      'SERVICE_STARTED',
      'RESOLVED'
    ];

    if (!status || !allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Allowed: ${allowedStatuses.join(', ')}`
      });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    const oldStatus = emergency.status;
    emergency.status = status;
    emergency.updated_at = new Date();

    if (status === 'RESOLVED') {
      emergency.resolved_at = new Date();
      emergency.resolution_note = resolution_note || 'Resolved by field rescue unit';
      // Free up assigned responders
      for (const ar of emergency.assigned_responders) {
        await User.findOneAndUpdate(
          { $or: [{ responder_id: ar.responder_id }, { _id: ar.responder_id.match(/^[0-9a-fA-F]{24}$/) ? ar.responder_id : null }] },
          { availability: 'AVAILABLE' }
        );
      }
    }

    await emergency.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: req.user.role,
      action: 'RESPONDER_CHANGED_STATUS',
      emergency_id: emergency.emergency_id,
      metadata: { old_status: oldStatus, new_status: status, resolution_note }
    });

    const notif = await Notification.create({
      user_id: emergency.user_id,
      target_role: 'ALL',
      type: 'STATUS_UPDATE',
      title: `⚡ Incident Status: ${status.replace(/_/g, ' ')}`,
      message: `Emergency ${emergency.emergency_id} updated to ${status.replace(/_/g, ' ')} by ${req.user.name}.`,
      emergency_id: emergency.emergency_id
    });
    emitNotification(notif);

    emitEmergencyStatusChanged(emergency);

    return res.status(200).json({
      success: true,
      message: `Status updated to ${status}`,
      emergency
    });
  } catch (err) {
    console.error('Status update error:', err);
    return res.status(500).json({ success: false, message: 'Error updating emergency status' });
  }
});

/**
 * @route   PATCH /api/responder/location
 * @desc    Broadcast actual browser/device GPS coordinates
 * @access  Responder
 */
router.patch('/location', async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    if (latitude === undefined || longitude === undefined || isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({ success: false, message: 'Valid numerical latitude and longitude required' });
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ success: false, message: 'Coordinates out of geographical range' });
    }

    const responderId = req.user.responder_id || req.user.id;

    await User.findByIdAndUpdate(req.user.id, {
      current_location: {
        latitude,
        longitude,
        updated_at: new Date()
      }
    });

    // Real-time Socket.IO emission
    emitResponderLocation(responderId, latitude, longitude);

    return res.status(200).json({
      success: true,
      message: 'Location updated',
      location: { latitude, longitude }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error updating GPS location' });
  }
});

/**
 * @route   PATCH /api/responder/availability
 * @desc    Toggle availability (AVAILABLE, BUSY, OFFLINE)
 * @access  Responder
 */
router.patch('/availability', async (req, res) => {
  try {
    const { availability } = req.body;

    if (!['AVAILABLE', 'BUSY', 'OFFLINE'].includes(availability)) {
      return res.status(400).json({ success: false, message: 'Valid availability: AVAILABLE, BUSY, OFFLINE' });
    }

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { availability },
      { new: true }
    ).select('-password');

    const responderId = req.user.responder_id || req.user.id;
    emitResponderStatus(responderId, availability);

    return res.status(200).json({
      success: true,
      message: `Availability set to ${availability}`,
      availability: user.availability
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error updating availability' });
  }
});

/**
 * @route   POST /api/responder/emergencies/:id/notes
 * @desc    Append incident note
 * @access  Responder / Admin
 */
router.post('/emergencies/:id/notes', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { note } = req.body;

    if (!note || !note.trim()) {
      return res.status(400).json({ success: false, message: 'Note text is required' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    const newNote = {
      author_id: req.user.id,
      author_name: req.user.name,
      author_role: req.user.role,
      note: note.trim(),
      created_at: new Date()
    };

    emergency.notes.push(newNote);
    emergency.updated_at = new Date();
    await emergency.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: req.user.role,
      action: 'ADDED_INCIDENT_NOTE',
      emergency_id: emergency.emergency_id,
      metadata: { note: note.trim() }
    });

    emitEmergencyUpdated(emergency);

    return res.status(201).json({
      success: true,
      message: 'Note added successfully',
      note: newNote,
      emergency
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error saving incident note' });
  }
});

/**
 * @route   POST /api/responder/emergencies/:id/escalation-request
 * @desc    Request priority escalation to Admin
 * @access  Responder
 */
router.post('/emergencies/:id/escalation-request', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const requested_priority = req.body.requested_priority || req.body.priority;
    const { reason } = req.body;

    if (!requested_priority || !['P1', 'P2', 'P3', 'P4'].includes(requested_priority)) {
      return res.status(400).json({ success: false, message: 'Valid priority required (P1, P2, P3, P4)' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    emergency.escalation_request = {
      requested_by: req.user.name,
      requested_priority,
      reason: reason || 'Field conditions deteriorated',
      timestamp: new Date(),
      status: 'PENDING'
    };
    emergency.updated_at = new Date();
    await emergency.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'RESPONDER',
      action: 'RESPONDER_REQUESTED_ESCALATION',
      emergency_id: emergency.emergency_id,
      metadata: { requested_priority, reason }
    });

    const notif = await Notification.create({
      user_id: null,
      target_role: 'ADMIN',
      type: 'ESCALATION_REQUEST',
      title: `⚠️ Priority Escalation Request: ${emergency.emergency_id}`,
      message: `${req.user.name} requested escalating ${emergency.emergency_id} to ${requested_priority}. Reason: ${reason || 'Field conditions deteriorated'}`,
      emergency_id: emergency.emergency_id,
      priority: requested_priority
    });
    emitNotification(notif);

    emitEmergencyUpdated(emergency);

    return res.status(200).json({
      success: true,
      message: 'Priority escalation request submitted to Command Center',
      escalation_request: emergency.escalation_request
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error requesting priority escalation' });
  }
});

/**
 * @route   POST /api/responder/emergencies/:id/chat
 * @desc    Send chat message
 * @access  Responder / Admin
 */
router.post('/emergencies/:id/chat', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { message, mode } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message content is required' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    const chatMsg = {
      sender_id: req.user.id,
      sender_name: req.user.name,
      sender_role: req.user.role,
      message: message.trim(),
      mode: mode || 'INTERNET',
      delivery_status: 'DELIVERED',
      timestamp: new Date()
    };

    emergency.chat_messages.push(chatMsg);
    emergency.updated_at = new Date();
    await emergency.save();

    emitChatMessage(emergencyId, chatMsg);

    return res.status(201).json({
      success: true,
      message: chatMsg
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error sending message' });
  }
});

/**
 * @route   GET /api/responder/history
 * @desc    Fetch past resolved missions for this responder
 * @access  Responder
 */
router.get('/history', async (req, res) => {
  try {
    const responderId = req.user.responder_id || req.user.id;
    const responderName = req.user.name;

    const history = await Emergency.find({
      status: { $in: ['RESOLVED', 'Cancelled', 'Resolved'] },
      $or: [
        { 'assigned_responders.responder_id': responderId },
        { 'assigned_responders.responder_id': req.user.id },
        { 'assigned_responders.name': responderName }
      ]
    }).sort({ resolved_at: -1, updated_at: -1, created_at: -1 });

    return res.status(200).json({
      success: true,
      count: history.length,
      history
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error retrieving responder history' });
  }
});

module.exports = router;

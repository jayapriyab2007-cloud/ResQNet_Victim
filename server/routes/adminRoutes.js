const express = require('express');
const router = express.Router();

const Emergency = require('../models/Emergency');
const User = require('../models/User');
const Notification = require('../models/Notification');
const AuditLog = require('../models/AuditLog');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  emitEmergencyAssigned,
  emitEmergencyUpdated,
  emitNotification
} = require('../services/socketService');

const bcrypt = require('bcryptjs');
const { validateEmail } = require('../utils/routing');

// Require authentication and ADMIN role for all routes in this router
router.use(requireAuth);
router.use(requireRole('ADMIN'));

/**
 * @route   GET /api/admin/emergencies
 * @desc    Fetch all emergencies with filtering and sorting
 * @access  Admin
 */
router.get('/emergencies', async (req, res) => {
  try {
    const { type, priority, status, search, sort } = req.query;
    let query = {};

    if (type && type !== 'ALL') {
      query.emergency_type = type;
    }

    if (priority && priority !== 'ALL') {
      query.priority = new RegExp(`^${priority}`, 'i');
    }

    if (status && status !== 'ALL') {
      query.status = status;
    }

    if (search && search.trim()) {
      const q = search.trim();
      query.$or = [
        { emergency_id: new RegExp(q, 'i') },
        { emergency_type: new RegExp(q, 'i') },
        { severity: new RegExp(q, 'i') },
        { message: new RegExp(q, 'i') }
      ];
    }

    let sortOption = { created_at: -1 };
    if (sort === 'PRIORITY') {
      // P1 -> P2 -> P3 -> P4
      sortOption = { priority: 1, created_at: -1 };
    }

    const emergencies = await Emergency.find(query).sort(sortOption);

    return res.status(200).json({
      success: true,
      count: emergencies.length,
      emergencies
    });
  } catch (err) {
    console.error('Error fetching admin emergencies:', err);
    return res.status(500).json({ success: false, message: 'Server error retrieving emergencies' });
  }
});

/**
 * @route   GET /api/admin/responders
 * @desc    Fetch all responder units with active status, assignments, and coordinates
 * @access  Admin
 */
router.get('/responders', async (req, res) => {
  try {
    const responders = await User.find({ role: 'RESPONDER' }).select('-password');

    // Attach active assignment if any
    const activeEmergencies = await Emergency.find({
      status: { $nin: ['RESOLVED', 'Cancelled'] },
      'assigned_responders.0': { $exists: true }
    });

    const enrichedResponders = responders.map(resp => {
      const rObj = resp.toObject();
      const currentEm = activeEmergencies.find(em =>
        em.assigned_responders.some(ar => ar.responder_id === rObj.responder_id || ar.responder_id === rObj._id.toString())
      );
      rObj.current_emergency_id = currentEm ? currentEm.emergency_id : null;
      return rObj;
    });

    return res.status(200).json({
      success: true,
      count: enrichedResponders.length,
      responders: enrichedResponders
    });
  } catch (err) {
    console.error('Error fetching responders:', err);
    return res.status(500).json({ success: false, message: 'Server error retrieving responders' });
  }
});

/**
 * @route   POST /api/admin/responders
 * @desc    Create/Onboard a new real responder unit
 * @access  Admin
 */
router.post('/responders', async (req, res) => {
  try {
    const { name, email, phone, password, specialization, team, blood_group } = req.body;

    if (!name || !email) {
      return res.status(400).json({ success: false, message: 'Name and email are required.' });
    }

    if (!validateEmail(email)) {
      return res.status(400).json({ success: false, message: 'Please enter a valid email address (e.g. name@gmail.com).' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      return res.status(400).json({ success: false, message: 'A user with this email already exists.' });
    }

    const defaultPass = password && password.length >= 6 ? password : 'responder123';
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(defaultPass, salt);

    const responderId = 'RSP-' + Math.random().toString(36).substring(2, 6).toUpperCase();

    const newResponder = new User({
      name: name.trim(),
      email: normalizedEmail,
      phone: phone ? phone.trim() : 'Not Provided',
      password: hashedPassword,
      blood_group: blood_group ? blood_group.trim() : 'O+',
      emergency_contact: phone ? phone.trim() : 'Not Specified',
      role: 'RESPONDER',
      responder_id: responderId,
      specialization: specialization ? specialization.trim() : 'Field Rescue Specialist',
      team: team ? team.trim() : 'Rapid Response Unit',
      availability: 'AVAILABLE',
      created_at: new Date()
    });

    await newResponder.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_CREATED_RESPONDER',
      target_user_id: responderId,
      metadata: { name: newResponder.name, email: newResponder.email, team: newResponder.team }
    }).catch(() => {});

    console.log(`🛡️ Admin onboarded new responder: ${newResponder.name} (${newResponder.email})`);

    const responderObj = newResponder.toObject();
    delete responderObj.password;

    return res.status(201).json({
      success: true,
      message: `Responder ${newResponder.name} registered successfully`,
      responder: responderObj
    });
  } catch (err) {
    console.error('Create responder error:', err);
    return res.status(500).json({ success: false, message: 'Server error registering responder' });
  }
});

/**
 * @route   DELETE /api/admin/responders/:id
 * @desc    Decommission / delete a responder
 * @access  Admin
 */
router.delete('/responders/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const responder = await User.findOne({
      $or: [
        { responder_id: id },
        { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null }
      ]
    });

    if (!responder) {
      return res.status(404).json({ success: false, message: 'Responder not found' });
    }

    await User.deleteOne({ _id: responder._id });

    // Remove from active emergency assignments
    await Emergency.updateMany(
      { 'assigned_responders.responder_id': responder.responder_id },
      { $pull: { assigned_responders: { responder_id: responder.responder_id } } }
    );

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_DECOMMISSIONED_RESPONDER',
      target_user_id: responder.responder_id || responder._id.toString(),
      metadata: { name: responder.name, email: responder.email }
    }).catch(() => {});

    return res.status(200).json({
      success: true,
      message: `Responder ${responder.name} deleted successfully`
    });
  } catch (err) {
    console.error('Delete responder error:', err);
    return res.status(500).json({ success: false, message: 'Server error deleting responder' });
  }
});

/**
 * @route   POST /api/admin/clear-demo-data
 * @desc    Purge any mock/demo items from database
 * @access  Admin
 */
router.post('/clear-demo-data', async (req, res) => {
  try {
    const demoEmailRegex = /(@resqnet\.com$|@resqnet\.org$|@example\.com$|@test\.com$)/i;
    const deletedUsers = await User.deleteMany({ email: { $regex: demoEmailRegex } });
    const deletedEmergencies = await Emergency.deleteMany({
      $or: [
        { user_id: { $regex: /^victim_demo/ } },
        { emergency_id: { $regex: /^RQ-20261005/ } }
      ]
    });

    return res.status(200).json({
      success: true,
      message: `Purged ${deletedUsers.deletedCount} demo users and ${deletedEmergencies.deletedCount} demo emergencies.`
    });
  } catch (err) {
    console.error('Clear demo data error:', err);
    return res.status(500).json({ success: false, message: 'Server error clearing demo data' });
  }
});

/**
 * @route   GET /api/admin/users
 * @desc    Fetch all users
 * @access  Admin
 */
router.get('/users', async (req, res) => {
  try {
    const users = await User.find().select('-password').sort({ created_at: -1 });
    return res.status(200).json({ success: true, count: users.length, users });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error retrieving users' });
  }
});

/**
 * @route   POST /api/admin/emergencies/:id/assign
 * @desc    Assign responder unit(s) to an emergency
 * @access  Admin
 */
router.post('/emergencies/:id/assign', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { responder_id, responder_name, role, team, is_primary } = req.body;

    if (!responder_id) {
      return res.status(400).json({ success: false, message: 'responder_id is required' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    // Check if responder exists in User collection
    const responderUser = await User.findOne({
      $or: [{ responder_id: responder_id }, { _id: responder_id.match(/^[0-9a-fA-F]{24}$/) ? responder_id : null }]
    });

    const finalName = responder_name || (responderUser ? responderUser.name : 'Tactical Responder');
    const finalRole = role || (responderUser ? responderUser.specialization : 'Rescue Unit');
    const finalTeam = team || (responderUser ? responderUser.team : emergency.assigned_team);

    // If is_primary, clear existing primary flags
    let updatedList = [...(emergency.assigned_responders || [])];
    if (is_primary) {
      updatedList = updatedList.map(r => ({ ...r, is_primary: false }));
    }

    // Check if responder already assigned
    const existingIndex = updatedList.findIndex(r => r.responder_id === responder_id);
    if (existingIndex !== -1) {
      updatedList[existingIndex].is_primary = is_primary !== undefined ? is_primary : updatedList[existingIndex].is_primary;
      updatedList[existingIndex].status = 'Assigned';
    } else {
      updatedList.push({
        responder_id,
        name: finalName,
        role: finalRole,
        team: finalTeam,
        is_primary: is_primary !== undefined ? is_primary : updatedList.length === 0,
        assigned_at: new Date(),
        status: 'Assigned'
      });
    }

    emergency.assigned_responders = updatedList;
    if (emergency.status === 'SOS_CREATED' || emergency.status === 'TEAM_NOTIFIED') {
      emergency.status = 'RESPONDER_ASSIGNED';
    }
    emergency.updated_at = new Date();
    await emergency.save();

    // Update responder availability to BUSY
    if (responderUser) {
      responderUser.availability = 'BUSY';
      await responderUser.save();
    }

    // Audit Log
    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_ASSIGNED_RESPONDER',
      emergency_id: emergency.emergency_id,
      target_user_id: responder_id,
      metadata: { responder_name: finalName, is_primary }
    });

    // Create Notification
    const notif = await Notification.create({
      user_id: responderUser ? responderUser._id.toString() : null,
      target_role: 'RESPONDER',
      type: 'MISSION_DISPATCH',
      title: `⚡ New Mission Assigned: ${emergency.emergency_id}`,
      message: `You have been assigned to ${emergency.emergency_type} (${emergency.priority}) at (${emergency.latitude.toFixed(4)}, ${emergency.longitude.toFixed(4)}).`,
      emergency_id: emergency.emergency_id,
      priority: emergency.priority
    });
    emitNotification(notif);

    // Socket.IO Emit
    emitEmergencyAssigned(emergency, responder_id);

    console.log(`🛡️ Admin dispatched ${finalName} to ${emergency.emergency_id}`);

    return res.status(200).json({
      success: true,
      message: `Assigned ${finalName} successfully`,
      emergency
    });
  } catch (err) {
    console.error('Assign responder error:', err);
    return res.status(500).json({ success: false, message: 'Server error assigning responder' });
  }
});

/**
 * @route   DELETE /api/admin/emergencies/:id/responders/:responder_id
 * @desc    Remove a responder unit from an emergency
 * @access  Admin
 */
router.delete('/emergencies/:id/responders/:responder_id', async (req, res) => {
  try {
    const { id: emergencyId, responder_id: responderId } = req.params;

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    emergency.assigned_responders = emergency.assigned_responders.filter(
      r => r.responder_id !== responderId
    );

    if (emergency.assigned_responders.length === 0 && emergency.status === 'RESPONDER_ASSIGNED') {
      emergency.status = 'TEAM_NOTIFIED';
    }

    emergency.updated_at = new Date();
    await emergency.save();

    // Reset responder availability
    const respUser = await User.findOne({
      $or: [{ responder_id: responderId }, { _id: responderId.match(/^[0-9a-fA-F]{24}$/) ? responderId : null }]
    });
    if (respUser) {
      respUser.availability = 'AVAILABLE';
      await respUser.save();
    }

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_REMOVED_RESPONDER',
      emergency_id: emergency.emergency_id,
      target_user_id: responderId
    });

    emitEmergencyUpdated(emergency);

    return res.status(200).json({
      success: true,
      message: 'Responder removed successfully',
      emergency
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error removing responder' });
  }
});

/**
 * @route   PATCH /api/admin/emergencies/:id/priority
 * @desc    Change / escalate incident priority
 * @access  Admin
 */
router.patch('/emergencies/:id/priority', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { priority, reason } = req.body;

    if (!priority || !['P1', 'P2', 'P3', 'P4'].includes(priority)) {
      return res.status(400).json({ success: false, message: 'Valid priority (P1, P2, P3, P4) is required' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    const oldPriority = emergency.priority;
    emergency.priority = priority;

    // Resolve any escalation request
    if (emergency.escalation_request && emergency.escalation_request.status === 'PENDING') {
      emergency.escalation_request.status = 'APPROVED';
    }

    emergency.updated_at = new Date();
    await emergency.save();

    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_CHANGED_PRIORITY',
      emergency_id: emergency.emergency_id,
      metadata: { old_priority: oldPriority, new_priority: priority, reason: reason || 'Admin command override' }
    });

    emitEmergencyUpdated(emergency);

    return res.status(200).json({
      success: true,
      message: `Priority updated from ${oldPriority} to ${priority}`,
      emergency
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error updating priority' });
  }
});

/**
 * @route   GET /api/admin/analytics
 * @desc    Aggregate operational stats for Dashboard
 * @access  Admin
 */
router.get('/analytics', async (req, res) => {
  try {
    const totalEmergencies = await Emergency.countDocuments();
    const activeEmergencies = await Emergency.countDocuments({
      status: { $nin: ['RESOLVED', 'Cancelled'] }
    });
    const criticalEmergencies = await Emergency.countDocuments({
      priority: 'P1',
      status: { $nin: ['RESOLVED', 'Cancelled'] }
    });
    const resolvedEmergencies = await Emergency.countDocuments({ status: 'RESOLVED' });

    const totalResponders = await User.countDocuments({ role: 'RESPONDER' });
    const availableResponders = await User.countDocuments({ role: 'RESPONDER', availability: 'AVAILABLE' });
    const busyResponders = await User.countDocuments({ role: 'RESPONDER', availability: 'BUSY' });

    return res.status(200).json({
      success: true,
      stats: {
        total_emergencies: totalEmergencies,
        active_emergencies: activeEmergencies,
        critical_emergencies: criticalEmergencies,
        resolved_emergencies: resolvedEmergencies,
        total_responders: totalResponders,
        available_responders: availableResponders,
        busy_responders: busyResponders,
        average_response_time: '06:15 min'
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error calculating analytics' });
  }
});

/**
 * @route   GET /api/admin/audit-logs
 * @desc    Fetch audit log history (read-only)
 * @access  Admin
 */
router.get('/audit-logs', async (req, res) => {
  try {
    const logs = await AuditLog.find().sort({ created_at: -1 }).limit(100);
    return res.status(200).json({ success: true, count: logs.length, logs });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error retrieving audit logs' });
  }
});

/**
 * @route   POST /api/admin/emergencies/:id/reassign
 * @desc    Reassign responder unit (remove previous, assign new)
 * @access  Admin
 */
router.post('/emergencies/:id/reassign', async (req, res) => {
  try {
    const emergencyId = req.params.id;
    const { responder_id, old_responder_id, responder_name, role, team } = req.body;

    if (!responder_id) {
      return res.status(400).json({ success: false, message: 'New responder_id is required' });
    }

    const emergency = await Emergency.findOne({ emergency_id: emergencyId });
    if (!emergency) {
      return res.status(404).json({ success: false, message: 'Emergency not found' });
    }

    // Free up old responder if provided
    if (old_responder_id) {
      await User.findOneAndUpdate(
        { $or: [{ responder_id: old_responder_id }, { _id: old_responder_id.match(/^[0-9a-fA-F]{24}$/) ? old_responder_id : null }] },
        { availability: 'AVAILABLE' }
      );
    }

    // Lookup new responder user
    const newResponderUser = await User.findOne({
      $or: [{ responder_id }, { _id: responder_id.match(/^[0-9a-fA-F]{24}$/) ? responder_id : null }]
    });

    const finalName = responder_name || (newResponderUser ? newResponderUser.name : 'Tactical Unit');
    const finalRole = role || (newResponderUser ? newResponderUser.specialization : 'Rescue Unit');
    const finalTeam = team || (newResponderUser ? newResponderUser.team : emergency.assigned_team);

    // Filter out old responder if specified, or reset list
    let updatedList = (emergency.assigned_responders || []).filter(
      r => r.responder_id !== old_responder_id && r.responder_id !== responder_id
    );

    updatedList.unshift({
      responder_id,
      name: finalName,
      role: finalRole,
      team: finalTeam,
      is_primary: true,
      assigned_at: new Date(),
      status: 'Assigned'
    });

    emergency.assigned_responders = updatedList;
    emergency.status = 'RESPONDER_ASSIGNED';
    emergency.updated_at = new Date();
    await emergency.save();

    // Mark new responder as BUSY
    if (newResponderUser) {
      newResponderUser.availability = 'BUSY';
      await newResponderUser.save();
    }

    // Audit log
    await AuditLog.create({
      user_id: req.user.id,
      user_name: req.user.name,
      role: 'ADMIN',
      action: 'ADMIN_REASSIGNED_RESPONDER',
      emergency_id: emergency.emergency_id,
      target_user_id: responder_id,
      metadata: { previous_responder: old_responder_id, new_responder: finalName }
    });

    // Notification
    const notif = await Notification.create({
      user_id: newResponderUser ? newResponderUser._id.toString() : null,
      target_role: 'RESPONDER',
      type: 'MISSION_REASSIGNED',
      title: `⚡ Reassigned Mission: ${emergency.emergency_id}`,
      message: `You have been reassigned to ${emergency.emergency_type} (${emergency.priority}).`,
      emergency_id: emergency.emergency_id,
      priority: emergency.priority
    });
    emitNotification(notif);

    emitEmergencyAssigned(emergency, responder_id);
    emitEmergencyUpdated(emergency);

    return res.status(200).json({
      success: true,
      message: `Reassigned to ${finalName} successfully`,
      emergency
    });
  } catch (err) {
    console.error('Reassign responder error:', err);
    return res.status(500).json({ success: false, message: 'Server error during reassignment' });
  }
});

/**
 * @route   GET /api/admin/history
 * @desc    Fetch resolved & historical emergency incidents
 * @access  Admin
 */
router.get('/history', async (req, res) => {
  try {
    const history = await Emergency.find({
      status: { $in: ['RESOLVED', 'Cancelled', 'Resolved'] }
    }).sort({ resolved_at: -1, updated_at: -1, created_at: -1 });

    return res.status(200).json({
      success: true,
      count: history.length,
      history
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error retrieving emergency history' });
  }
});

module.exports = router;

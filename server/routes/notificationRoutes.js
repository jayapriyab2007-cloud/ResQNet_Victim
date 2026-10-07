const express = require('express');
const router = express.Router();

const Notification = require('../models/Notification');
const { requireAuth } = require('../middleware/auth');

// Optional authentication: if token is present, use user info; else support public query
router.get('/', async (req, res) => {
  try {
    const { user_id, role } = req.query;
    let query = {};

    if (user_id) {
      query.$or = [{ user_id: user_id }, { target_role: 'ALL' }];
    } else if (role) {
      query.$or = [{ target_role: role.toUpperCase() }, { target_role: 'ALL' }];
    }

    const notifications = await Notification.find(query).sort({ created_at: -1 }).limit(50);
    return res.status(200).json({ success: true, count: notifications.length, notifications });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error retrieving notifications' });
  }
});

router.patch('/:id/read', async (req, res) => {
  try {
    const notification = await Notification.findByIdAndUpdate(
      req.params.id,
      { read: true },
      { new: true }
    );
    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    return res.status(200).json({ success: true, notification });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error updating notification' });
  }
});

router.patch('/read-all', async (req, res) => {
  try {
    const { user_id, role } = req.body;
    let query = {};
    if (user_id) query.user_id = user_id;
    if (role) query.target_role = role.toUpperCase();

    await Notification.updateMany(query, { read: true });
    return res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Error marking notifications as read' });
  }
});

module.exports = router;

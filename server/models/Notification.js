const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  user_id: {
    type: String,
    index: true
  },
  target_role: {
    type: String,
    enum: ['ALL', 'ADMIN', 'RESPONDER', 'VICTIM'],
    default: 'ALL'
  },
  type: {
    type: String,
    required: true
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  emergency_id: {
    type: String,
    index: true
  },
  priority: {
    type: String,
    default: 'NORMAL'
  },
  read: {
    type: Boolean,
    default: false,
    index: true
  },
  created_at: {
    type: Date,
    default: Date.now,
    index: true
  }
});

module.exports = mongoose.model('Notification', notificationSchema);

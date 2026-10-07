const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  user_id: {
    type: String,
    required: true,
    index: true
  },
  user_name: {
    type: String,
    default: 'System'
  },
  role: {
    type: String,
    required: true
  },
  action: {
    type: String,
    required: true
  },
  emergency_id: {
    type: String,
    index: true
  },
  target_user_id: {
    type: String
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed
  },
  created_at: {
    type: Date,
    default: Date.now,
    index: true
  }
});

module.exports = mongoose.model('AuditLog', auditLogSchema);

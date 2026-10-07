const mongoose = require('mongoose');

const passwordResetSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true
  },
  otp_hash: {
    type: String,
    required: true
  },
  expires_at: {
    type: Date,
    required: true
  },
  used: {
    type: Boolean,
    default: false
  },
  created_at: {
    type: Date,
    default: Date.now
  }
}, {
  collection: 'passwordresets'
});

module.exports = mongoose.model('PasswordReset', passwordResetSchema);

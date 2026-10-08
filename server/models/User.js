const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Full name is required'],
    trim: true
  },
  phone: {
    type: String,
    required: [true, 'Phone number is required'],
    trim: true
  },
  email: {
    type: String,
    required: [true, 'Email address is required'],
    unique: true,
    lowercase: true,
    trim: true,
    index: true
  },
  password: {
    type: String,
    required: [true, 'Password is required']
  },
  blood_group: {
    type: String,
    trim: true,
    default: 'O+'
  },
  emergency_contact: {
    type: String,
    trim: true,
    default: 'Not Specified'
  },
  role: {
    type: String,
    enum: ['VICTIM', 'RESPONDER', 'ADMIN'],
    default: 'VICTIM',
    index: true
  },
  responder_id: {
    type: String,
    sparse: true,
    index: true
  },
  specialization: {
    type: String,
    default: '',
    trim: true
  },
  team: {
    type: String,
    default: '',
    trim: true
  },
  availability: {
    type: String,
    enum: ['AVAILABLE', 'BUSY', 'OFFLINE'],
    default: 'AVAILABLE',
    index: true
  },
  current_location: {
    latitude: { type: Number },
    longitude: { type: Number },
    updated_at: { type: Date }
  },
  connection_status: {
    type: String,
    default: 'ONLINE'
  },
  created_at: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('User', userSchema);

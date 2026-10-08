const mongoose = require('mongoose');

const emergencySchema = new mongoose.Schema({
  emergency_id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  user_id: {
    type: String,
    required: [true, 'user_id is required'],
    index: true
  },
  emergency_type: {
    type: String,
    required: [true, 'emergency_type is required'],
    trim: true
  },
  severity: {
    type: String,
    required: [true, 'severity is required'],
    trim: true
  },
  priority: {
    type: String,
    required: true,
    enum: ['P1', 'P2', 'P3', 'P4'],
    index: true
  },
  people_affected: {
    type: Number,
    default: 1
  },
  message: {
    type: String,
    default: '',
    trim: true
  },
  latitude: {
    type: Number,
    required: [true, 'Valid latitude is required']
  },
  longitude: {
    type: Number,
    required: [true, 'Valid longitude is required']
  },
  location_source: {
    type: String,
    default: 'gps',
    trim: true
  },
  assigned_team: {
    type: String,
    required: true,
    trim: true
  },
  source: {
    type: String,
    default: 'WEB',
    trim: true
  },
  lora_metadata: {
    rssi: { type: Number },
    snr: { type: Number },
    node_id: { type: String },
    battery_level: { type: Number },
    frequency: { type: String },
    gateway_id: { type: String },
    raw_packet: { type: String },
    received_at: { type: Date }
  },
  status: {
    type: String,
    default: 'SOS_CREATED',
    enum: [
      'SOS_CREATED',
      'SOS_SENT',
      'SERVER_RECEIVED',
      'TEAM_NOTIFIED',
      'TEAM_ACKNOWLEDGED',
      'RESPONDER_ASSIGNED',
      'RESPONDER_ACCEPTED',
      'ON_THE_WAY',
      'ARRIVED',
      'SERVICE_STARTED',
      'RESOLVED',
      'Cancelled'
    ],
    index: true
  },
  assigned_responders: [
    {
      responder_id: { type: String, required: true },
      name: { type: String },
      role: { type: String },
      team: { type: String },
      is_primary: { type: Boolean, default: false },
      assigned_at: { type: Date, default: Date.now },
      accepted_at: { type: Date },
      status: { type: String, default: 'Assigned' }
    }
  ],
  escalation_request: {
    requested_by: { type: String },
    requested_priority: { type: String },
    reason: { type: String },
    timestamp: { type: Date },
    status: { type: String, enum: ['PENDING', 'APPROVED', 'REJECTED'], default: 'PENDING' }
  },
  notes: [
    {
      author_id: { type: String },
      author_name: { type: String },
      author_role: { type: String },
      note: { type: String },
      created_at: { type: Date, default: Date.now }
    }
  ],
  chat_messages: [
    {
      sender_id: { type: String },
      sender_name: { type: String },
      sender_role: { type: String },
      message: { type: String },
      mode: { type: String, default: 'INTERNET' },
      delivery_status: { type: String, default: 'DELIVERED' },
      timestamp: { type: Date, default: Date.now }
    }
  ],
  last_location_update: {
    latitude: { type: Number },
    longitude: { type: Number },
    timestamp: { type: Date }
  },
  resolved_at: {
    type: Date
  },
  resolution_note: {
    type: String,
    default: ''
  },
  created_at: {
    type: Date,
    default: Date.now,
    index: true
  },
  updated_at: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Emergency', emergencySchema);

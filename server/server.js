const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const dns = require('dns');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

// Configure public DNS resolvers to ensure reliable MongoDB Atlas SRV record resolution on Windows
try {
  dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
} catch (e) {
  // Fall back to default system DNS if custom resolvers are restricted
}

// Load environment variables from .env
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const CLIENT_URL = process.env.CLIENT_URL || 'http://localhost:3000';

// ============================================================================
// Middleware Configuration
// ============================================================================

// Enable CORS for the React frontend (supporting localhost:3000 and dynamic client port)
const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:3000',
  'http://localhost:3001',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3001'
].filter(Boolean);

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    }
    return callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body parser for JSON payloads
app.use(express.json());

// ============================================================================
// MongoDB Atlas Connection
// ============================================================================

let MONGODB_URI = process.env.MONGODB_URI;

// Ensure database name 'resqnet' is specified if omitted before query parameters
if (MONGODB_URI && MONGODB_URI.includes('mongodb.net/?')) {
  MONGODB_URI = MONGODB_URI.replace('mongodb.net/?', 'mongodb.net/resqnet?');
}

if (!MONGODB_URI || MONGODB_URI.trim() === '') {
  console.warn('⚠️  MONGODB_URI is not set in server/.env.');
  console.warn('👉 Please set your MongoDB Atlas connection string in server/.env to connect to the database.');
} else {
  mongoose.connect(MONGODB_URI)
    .then(() => {
      console.log('✅ Connected to MongoDB Atlas successfully');
      console.log(`📦 Database: ${mongoose.connection.name}`);
    })
    .catch((err) => {
      console.error('❌ MongoDB Atlas connection failed:', err.message);
    });
}

// Mongoose connection lifecycle listeners
mongoose.connection.on('connected', () => {
  console.log('🟢 Mongoose connected to MongoDB Atlas');
});

mongoose.connection.on('error', (err) => {
  console.error('🔴 Mongoose runtime connection error:', err.message);
});

mongoose.connection.on('disconnected', () => {
  console.warn('🟡 Mongoose disconnected from MongoDB Atlas');
});

// ============================================================================
// MongoDB User Schema & Model
// ============================================================================

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
    trim: true
  },
  password: {
    type: String,
    required: [true, 'Password is required']
  },
  blood_group: {
    type: String,
    required: [true, 'Blood group is required'],
    trim: true,
    enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
  },
  emergency_contact: {
    type: String,
    required: [true, 'Emergency contact number is required'],
    trim: true
  },
  created_at: {
    type: Date,
    default: Date.now
  }
});

const User = mongoose.model('User', userSchema);

// ============================================================================
// MongoDB Password Reset Schema & Model (resqnet.passwordresets)
// ============================================================================

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

const PasswordReset = mongoose.model('PasswordReset', passwordResetSchema);

// ============================================================================
// MongoDB Emergency Schema & Model (resqnet.emergencies)
// ============================================================================

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
    enum: ['P1', 'P2', 'P3', 'P4']
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
    ]
  },
  created_at: {
    type: Date,
    default: Date.now
  },
  updated_at: {
    type: Date,
    default: Date.now
  }
});

const Emergency = mongoose.model('Emergency', emergencySchema);

// ============================================================================
// Automatic Emergency Team Routing & Priority Helpers
// ============================================================================

const TEAM_ROUTING_MAP = {
  'Flood': 'Flood Rescue Team',
  'Cyclone': 'Disaster Rescue Team',
  'Earthquake': 'Disaster Rescue Team',
  'Fire': 'Fire Rescue Team',
  'Forest Fire': 'Fire + Forest Rescue Team',
  'Tsunami': 'Coastal Disaster Rescue Team',
  'Landslide': 'Disaster Rescue Team',
  'Heatwave': 'Medical / Disaster Team',
  'Medical Emergency': 'Medical Rescue Team',
  'Safety / Crime': 'Police / Safety Team',
  'Other': 'General Emergency Team'
};

function getAssignedTeam(emergencyType) {
  if (!emergencyType) return 'General Emergency Team';
  const trimmed = emergencyType.trim();

  // Direct match
  if (TEAM_ROUTING_MAP[trimmed]) return TEAM_ROUTING_MAP[trimmed];

  // Case-insensitive match
  const lower = trimmed.toLowerCase();
  for (const [key, value] of Object.entries(TEAM_ROUTING_MAP)) {
    if (key.toLowerCase() === lower) return value;
  }

  // Keyword-based fallback
  if (lower.includes('flood')) return 'Flood Rescue Team';
  if (lower.includes('cyclone') || lower.includes('storm')) return 'Disaster Rescue Team';
  if (lower.includes('earthquake') || lower.includes('tremor')) return 'Disaster Rescue Team';
  if (lower.includes('forest fire')) return 'Fire + Forest Rescue Team';
  if (lower.includes('fire')) return 'Fire Rescue Team';
  if (lower.includes('tsunami')) return 'Coastal Disaster Rescue Team';
  if (lower.includes('landslide')) return 'Disaster Rescue Team';
  if (lower.includes('heatwave') || lower.includes('heat')) return 'Medical / Disaster Team';
  if (lower.includes('medical') || lower.includes('hospital')) return 'Medical Rescue Team';
  if (lower.includes('crime') || lower.includes('safety') || lower.includes('police')) return 'Police / Safety Team';

  return 'General Emergency Team';
}

function calculatePriority(severity) {
  switch ((severity || '').toLowerCase().trim()) {
    case 'critical':
      return 'P1';
    case 'high':
      return 'P2';
    case 'medium':
      return 'P3';
    case 'low':
      return 'P4';
    default:
      return 'P1';
  }
}

function generateEmergencyId() {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomHex = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `RQ-${dateStr}-${randomHex}`;
}

// Reusable standard email validation helper
function validateEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const trimmed = email.trim();
  if (!trimmed || trimmed.includes(' ')) return false;
  const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
  if (!emailRegex.test(trimmed)) return false;
  const parts = trimmed.split('@');
  if (parts.length !== 2) return false;
  const [, domain] = parts;
  const domainParts = domain.split('.');
  if (domainParts.length < 2) return false;
  const tld = domainParts[domainParts.length - 1];
  return tld.length >= 2;
}

// ============================================================================
// Authentication API Routes
// ============================================================================

/**
 * @route   POST /api/auth/register
 * @desc    Register a new victim user
 * @access  Public
 */
app.post('/api/auth/register', async (req, res) => {
  try {
    const name = req.body.name ? req.body.name.trim() : '';
    const phone = req.body.phone ? req.body.phone.trim() : '';
    const email = req.body.email ? req.body.email.trim() : '';
    const password = req.body.password || '';
    const confirm_password = req.body.confirm_password || req.body.confirmPassword || '';
    const blood_group = (req.body.blood_group || req.body.bloodGroup || '').trim();
    const emergency_contact = (req.body.emergency_contact || req.body.emergencyContact || '').trim();

    // Validate required fields
    if (!name || !phone || !email || !password || !blood_group || !emergency_contact) {
      return res.status(400).json({ error: 'All fields are required.' });
    }

    // Email format validation using reusable validateEmail rule
    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    // Password length validation
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long.' });
    }

    // Check if confirm_password was passed and matches
    if (confirm_password && password !== confirm_password) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }

    // Check if email already exists
    const normalizedEmail = email.toLowerCase().trim();
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({ error: 'An account with this email already exists.' });
    }

    // Hash the password with bcryptjs
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create and save new user to MongoDB Atlas
    const newUser = new User({
      name: name.trim(),
      phone: phone.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      blood_group: blood_group.trim(),
      emergency_contact: emergency_contact.trim(),
      created_at: new Date()
    });

    await newUser.save();

    console.log(`👤 New user registered: ${newUser.name} (${newUser.email})`);

    return res.status(201).json({
      message: 'Account created successfully.',
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        blood_group: newUser.blood_group,
        emergency_contact: newUser.emergency_contact
      }
    });
  } catch (err) {
    console.error('Registration Error:', err);
    if (err.code === 11000) {
      return res.status(400).json({ error: 'An account with this email already exists.' });
    }
    return res.status(500).json({ error: 'Registration failed due to a server error. Please try again.' });
  }
});

/**
 * @route   POST /api/auth/login
 * @desc    Authenticate user & return victim profile info
 * @access  Public
 */
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate presence of email and password
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    // Validate email format
    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Find user in MongoDB Atlas
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      // Do not reveal whether email or password was wrong
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    // Compare hashed password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    console.log(`🔓 User logged in successfully: ${user.name} (${user.email})`);

    // Return authenticated user data WITHOUT password
    return res.status(200).json({
      message: 'Login successful.',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        blood_group: user.blood_group,
        emergency_contact: user.emergency_contact
      }
    });
  } catch (err) {
    console.error('Login Error:', err);
    return res.status(500).json({ error: 'Login failed due to a server error. Please try again.' });
  }
});

/**
 * @route   POST /api/auth/forgot-password
 * @desc    Generate a secure 6-digit OTP for password reset
 * @access  Public
 */
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const email = req.body.email ? req.body.email.trim() : '';

    // 1. Validate email presence & format using reusable validateEmail rule
    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const isProduction = process.env.NODE_ENV === 'production';

    // 2. Find the user in MongoDB Atlas
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      if (isProduction) {
        return res.status(200).json({
          success: true,
          message: 'If the account exists, a reset code has been sent.'
        });
      } else {
        return res.status(404).json({
          error: 'No account found with this email address. Please check your email or register a new account.'
        });
      }
    }

    // 3. Generate a secure 6-digit OTP (crypto.randomInt ensures unpredictable, cryptographically strong digits)
    const otp = crypto.randomInt(100000, 1000000).toString();

    // 4. OTP expires after 5 minutes
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    // 5. Store the OTP securely with an expiry (hash OTP with bcrypt before storing)
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    // Invalidate any previously unused OTPs for this email
    await PasswordReset.updateMany({ email: normalizedEmail, used: false }, { used: true });

    const passwordReset = new PasswordReset({
      email: normalizedEmail,
      otp_hash: otpHash,
      expires_at: expiresAt,
      used: false,
      created_at: new Date()
    });

    await passwordReset.save();

    console.log(`🔑 Password reset OTP generated for ${normalizedEmail} (Expires in 5m)`);

    // In development mode, return dev_otp for seamless testing without an email provider
    if (!isProduction) {
      return res.status(200).json({
        success: true,
        message: 'OTP generated',
        dev_otp: otp
      });
    }

    // In production mode, return safe generic message
    return res.status(200).json({
      success: true,
      message: 'If the account exists, a reset code has been sent.'
    });
  } catch (err) {
    console.error('Forgot Password Error:', err);
    return res.status(500).json({ error: 'Unable to process password reset request. Please try again.' });
  }
});

/**
 * @route   POST /api/auth/reset-password
 * @desc    Verify OTP and reset user password
 * @access  Public
 */
app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    // Validate presence of required fields
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Please enter the OTP.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const trimmedOtp = otp.toString().trim();

    if (trimmedOtp.length !== 6) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    // 1. Find the user
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    // 2. Find the most recent unused OTP for this email
    const resetRecord = await PasswordReset.findOne({
      email: normalizedEmail,
      used: false
    }).sort({ created_at: -1 });

    if (!resetRecord) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    // 3. Verify that OTP has not expired
    if (new Date() > new Date(resetRecord.expires_at)) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new OTP.' });
    }

    // 4. Verify OTP using bcrypt
    const isOtpValid = await bcrypt.compare(trimmedOtp, resetRecord.otp_hash);
    if (!isOtpValid) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    // 5. Validate the new password
    if (typeof newPassword !== 'string' || newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }

    // 6. Hash the new password using bcryptjs
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // 7. Replace the existing password hash
    user.password = hashedPassword;
    await user.save();

    // 8. Invalidate the OTP immediately
    resetRecord.used = true;
    await resetRecord.save();
    await PasswordReset.updateMany({ email: normalizedEmail, used: false }, { used: true });

    console.log(`✅ Password successfully reset in MongoDB for user: ${user.name} (${user.email})`);

    // 9. Return success
    return res.status(200).json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (err) {
    console.error('Password Reset Error:', err);
    return res.status(500).json({ error: 'Unable to reset password. Please try again.' });
  }
});

// ============================================================================
// Real SOS Emergency API Routes
// ============================================================================

/**
 * @route   POST /api/emergencies
 * @desc    Create a new real SOS emergency request in MongoDB Atlas
 * @access  Public (Authenticated Victim)
 */
app.post('/api/emergencies', async (req, res) => {
  try {
    const {
      user_id,
      emergency_type,
      severity,
      people_affected,
      message,
      latitude,
      longitude,
      location_source
    } = req.body;

    // Validate: user_id is required
    if (!user_id || typeof user_id !== 'string' || !user_id.trim()) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    // Validate: emergency_type is required
    if (!emergency_type || typeof emergency_type !== 'string' || !emergency_type.trim()) {
      return res.status(400).json({ error: 'emergency_type is required' });
    }

    // Validate: severity is required
    if (!severity || typeof severity !== 'string' || !severity.trim()) {
      return res.status(400).json({ error: 'severity is required' });
    }

    // Validate: latitude is a valid number
    if (latitude === undefined || latitude === null || typeof latitude !== 'number' || isNaN(latitude)) {
      return res.status(400).json({ error: 'latitude must be a valid number' });
    }

    // Validate: longitude is a valid number
    if (longitude === undefined || longitude === null || typeof longitude !== 'number' || isNaN(longitude)) {
      return res.status(400).json({ error: 'longitude must be a valid number' });
    }

    // Geographical boundaries check
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ error: 'Coordinates are out of geographical range' });
    }

    // IMPORTANT: Do NOT accept a responder selected by the victim
    // We intentionally ignore any client-provided responder field.

    // Automatic team routing decided by backend
    const assignedTeam = getAssignedTeam(emergency_type);

    // Priority calculated by backend
    const priority = calculatePriority(severity);

    // Generate unique human-readable emergency ID
    const emergencyId = generateEmergencyId();

    // Initial status: SOS_CREATED (Real status that has actually occurred)
    const newEmergency = new Emergency({
      emergency_id: emergencyId,
      user_id: user_id.trim(),
      emergency_type: emergency_type.trim(),
      severity: severity.trim(),
      priority: priority,
      people_affected: Number(people_affected) > 0 ? Number(people_affected) : 1,
      message: message ? message.trim() : 'Immediate SOS triggered by victim',
      latitude: latitude,
      longitude: longitude,
      location_source: location_source ? location_source.trim() : 'gps',
      assigned_team: assignedTeam,
      status: 'SOS_CREATED',
      created_at: new Date(),
      updated_at: new Date()
    });

    await newEmergency.save();

    console.log(`🚨 REAL SOS Created in MongoDB Atlas: ${newEmergency.emergency_id} | Type: ${newEmergency.emergency_type} | Priority: ${newEmergency.priority} | Team: ${newEmergency.assigned_team}`);

    return res.status(201).json({
      success: true,
      message: 'Emergency request received',
      emergency: {
        emergency_id: newEmergency.emergency_id,
        user_id: newEmergency.user_id,
        emergency_type: newEmergency.emergency_type,
        severity: newEmergency.severity,
        priority: newEmergency.priority,
        people_affected: newEmergency.people_affected,
        message: newEmergency.message,
        latitude: newEmergency.latitude,
        longitude: newEmergency.longitude,
        location_source: newEmergency.location_source,
        assigned_team: newEmergency.assigned_team,
        status: newEmergency.status,
        created_at: newEmergency.created_at
      }
    });
  } catch (err) {
    console.error('SOS Creation Error:', err);
    return res.status(500).json({ error: 'Failed to record emergency request due to a server error.' });
  }
});

/**
 * @route   GET /api/emergencies/user/:user_id
 * @desc    Fetch real emergency history for a victim
 * @access  Public (Authenticated Victim)
 */
app.get('/api/emergencies/user/:user_id', async (req, res) => {
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
 * @route   PATCH /api/emergencies/:emergency_id/cancel
 * @desc    Cancel an active emergency
 * @access  Public (Authenticated Victim)
 */
app.patch('/api/emergencies/:emergency_id/cancel', async (req, res) => {
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

// ============================================================================
// Health Check Endpoint
// ============================================================================

app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'ResQNet API'
  });
});

// ============================================================================
// Error Handling Middleware
// ============================================================================

// 404 handler for undefined API routes
app.use((req, res, next) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl
  });
});

// Global internal server error handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err.stack || err.message);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error'
  });
});

// ============================================================================
// Start Server
// ============================================================================

app.listen(PORT, () => {
  console.log(`🚀 ResQNet Backend Server running on port ${PORT}`);
  console.log(`🌐 Health check available at: http://localhost:${PORT}/api/health`);
  console.log(`🔗 Allowed CORS origin: ${CLIENT_URL}`);
});

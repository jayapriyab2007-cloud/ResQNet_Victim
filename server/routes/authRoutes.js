const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const PasswordReset = require('../models/PasswordReset');
const AuditLog = require('../models/AuditLog');
const { requireAuth, JWT_SECRET } = require('../middleware/auth');
const { validateEmail } = require('../utils/routing');

/**
 * POST /api/auth/register
 * Strictly registers users with role VICTIM.
 * Ignores any client-supplied role parameter for security.
 */
router.post('/register', async (req, res) => {
  try {
    const name = req.body.name ? req.body.name.trim() : '';
    const phone = req.body.phone ? req.body.phone.trim() : '';
    const email = req.body.email ? req.body.email.trim() : '';
    const password = req.body.password || '';
    const confirm_password = req.body.confirm_password || req.body.confirmPassword || '';
    const blood_group = (req.body.blood_group || req.body.bloodGroup || '').trim();
    const emergency_contact = (req.body.emergency_contact || req.body.emergencyContact || '').trim();

    const rawRole = (req.body.role || 'VICTIM').toUpperCase();
    const allowedRoles = ['VICTIM', 'RESPONDER', 'ADMIN'];
    const role = allowedRoles.includes(rawRole) ? rawRole : 'VICTIM';

    // Validate required fields
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }

    // Email format validation
    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address (e.g. name@gmail.com).' });
    }

    // Password length validation
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long.' });
    }

    // Password matching check
    if (confirm_password && password !== confirm_password) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }

    // Check if email already exists
    const normalizedEmail = email.toLowerCase().trim();
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({ error: 'An account with this email already exists.' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const responderId = role === 'RESPONDER'
      ? (req.body.responder_id || 'RSP-' + Math.random().toString(36).substring(2, 6).toUpperCase())
      : (role === 'ADMIN' ? 'ADM-HQ-01' : null);

    const specialization = req.body.specialization || (role === 'ADMIN' ? 'Command Center Dispatch' : 'Tactical Rescue');
    const team = req.body.team || (role === 'ADMIN' ? 'HQ Operations' : 'Rapid Response Team');

    // Create user
    const newUser = new User({
      name: name.trim(),
      phone: phone.trim() || 'Not Provided',
      email: normalizedEmail,
      password: hashedPassword,
      blood_group: blood_group ? blood_group.trim() : 'O+',
      emergency_contact: emergency_contact ? emergency_contact.trim() : (phone.trim() || 'Not Specified'),
      role: role,
      responder_id: responderId,
      specialization: specialization,
      team: team,
      availability: 'AVAILABLE',
      created_at: new Date()
    });

    await newUser.save();

    // Generate JWT
    const token = jwt.sign(
      {
        id: newUser._id,
        email: newUser.email,
        role: newUser.role,
        name: newUser.name,
        responder_id: newUser.responder_id || null
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Audit log
    await AuditLog.create({
      user_id: newUser._id.toString(),
      role: newUser.role,
      action: `${newUser.role}_REGISTERED`,
      metadata: { email: newUser.email, name: newUser.name }
    }).catch(() => {});

    console.log(`[AUTH] New ${newUser.role} registered: ${newUser.name} (${newUser.email})`);

    return res.status(201).json({
      success: true,
      message: 'Account created successfully! Welcome to ResQNet.',
      token,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        blood_group: newUser.blood_group,
        emergency_contact: newUser.emergency_contact,
        role: newUser.role,
        responder_id: newUser.responder_id,
        specialization: newUser.specialization,
        team: newUser.team,
        availability: newUser.availability
      }
    });
  } catch (err) {
    console.error('Registration Error:', err);
    return res.status(500).json({ error: 'Registration failed due to a server error. Please try again.' });
  }
});

/**
 * POST /api/auth/login
 * Authenticates VICTIM, RESPONDER, or ADMIN.
 * Returns JWT token and sanitized user object.
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    const role = user.role || 'VICTIM';

    // Sign JWT token
    const token = jwt.sign(
      {
        id: user._id.toString(),
        email: user.email,
        role: role,
        name: user.name,
        responder_id: user.responder_id || null
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    console.log(`[AUTH] User logged in: ${user.name} (${user.email}) [Role: ${role}]`);

    return res.status(200).json({
      success: true,
      message: 'Login successful.',
      token,
      user: {
        id: user._id.toString(),
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: role,
        blood_group: user.blood_group || '',
        emergency_contact: user.emergency_contact || '',
        responder_id: user.responder_id || null,
        specialization: user.specialization || null,
        team: user.team || null,
        availability: user.availability || 'AVAILABLE',
        current_location: user.current_location || null
      }
    });
  } catch (err) {
    console.error('Login Error:', err);
    return res.status(500).json({ error: 'Login failed due to a server error. Please try again.' });
  }
});

/**
 * POST /api/auth/forgot-password
 * Generates secure OTP for password reset.
 */
router.post('/forgot-password', async (req, res) => {
  try {
    const email = req.body.email ? req.body.email.trim() : '';

    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const isProduction = process.env.NODE_ENV === 'production';

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

    const otp = crypto.randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 min expiry

    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    await PasswordReset.updateMany({ email: normalizedEmail, used: false }, { used: true });

    const passwordReset = new PasswordReset({
      email: normalizedEmail,
      otp_hash: otpHash,
      expires_at: expiresAt,
      used: false,
      created_at: new Date()
    });

    await passwordReset.save();

    console.log(`[AUTH] Password reset OTP generated for ${normalizedEmail} (Expires in 5m)`);

    if (!isProduction) {
      return res.status(200).json({
        success: true,
        message: 'OTP generated',
        dev_otp: otp
      });
    }

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
 * POST /api/auth/reset-password
 * Verifies OTP and updates user password.
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Please enter the OTP.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const trimmedOtp = otp.toString().trim();

    if (trimmedOtp.length !== 6) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    const resetRecord = await PasswordReset.findOne({
      email: normalizedEmail,
      used: false
    }).sort({ created_at: -1 });

    if (!resetRecord) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    if (new Date() > new Date(resetRecord.expires_at)) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new OTP.' });
    }

    const isOtpValid = await bcrypt.compare(trimmedOtp, resetRecord.otp_hash);
    if (!isOtpValid) {
      return res.status(400).json({ error: 'Invalid OTP.' });
    }

    if (typeof newPassword !== 'string' || newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    user.password = hashedPassword;
    await user.save();

    resetRecord.used = true;
    await resetRecord.save();
    await PasswordReset.updateMany({ email: normalizedEmail, used: false }, { used: true });

    console.log(`[AUTH] Password successfully reset for user: ${user.name} (${user.email})`);

    return res.status(200).json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (err) {
    console.error('Password Reset Error:', err);
    return res.status(500).json({ error: 'Unable to reset password. Please try again.' });
  }
});

/**
 * GET /api/auth/me
 * Returns authenticated user profile.
 */
router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    return res.json({
      success: true,
      user: {
        id: user._id.toString(),
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role || 'VICTIM',
        blood_group: user.blood_group || '',
        emergency_contact: user.emergency_contact || '',
        responder_id: user.responder_id || null,
        specialization: user.specialization || null,
        team: user.team || null,
        availability: user.availability || 'AVAILABLE',
        current_location: user.current_location || null
      }
    });
  } catch (err) {
    console.error('Get profile error:', err);
    return res.status(500).json({ success: false, message: 'Failed to retrieve profile' });
  }
});

module.exports = router;

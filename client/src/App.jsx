import React, { useState, useEffect, useRef } from 'react';
import L from 'leaflet';

/**
 * ============================================================================
 * RESQNET VICTIM APPLICATION (React + Vite + Leaflet)
 * ============================================================================
 * Full Onboarding Flow:
 * Welcome → What is ResQNet? → How It Works → Features → Login/Register → Home
 *
 * Core navigation once authenticated:
 * Home (create emergency) | Live Status (monitor emergency) | History | Profile
 *
 * NOTE: The victim NEVER connects directly to MongoDB and CANNOT assign
 * responders. All routing & responder assignment is handled by the backend.
 * ============================================================================
 */

// 11 Emergency Categories (including Heatwave per Part 8)
const EMERGENCY_CATEGORIES = [
  { id: 'flood', name: 'Flood', emoji: '🌊', team: 'Flood Rescue Team', desc: 'Rising flood waters, flash floods, or water stagnation' },
  { id: 'cyclone', name: 'Cyclone', emoji: '🌀', team: 'Disaster Rescue Team', desc: 'High wind hazard, storm surge, or cyclone alert' },
  { id: 'earthquake', name: 'Earthquake', emoji: '🌍', team: 'Disaster Rescue Team', desc: 'Tremors, building damage, or aftershocks' },
  { id: 'fire', name: 'Fire', emoji: '🔥', team: 'Fire Rescue Team', desc: 'Building fire, smoke trap, or explosion hazard' },
  { id: 'forest_fire', name: 'Forest Fire', emoji: '🌲', team: 'Fire + Forest Rescue Team', desc: 'Spreading brush fire or forest edge hazard' },
  { id: 'tsunami', name: 'Tsunami', emoji: '🌊', team: 'Coastal Disaster Rescue Team', desc: 'Coastal wave warning or ocean surge' },
  { id: 'landslide', name: 'Landslide', emoji: '⛰️', team: 'Disaster Rescue Team', desc: 'Mudslide, rockfall, or road blockage' },
  { id: 'heatwave', name: 'Heatwave', emoji: '☀️', team: 'Medical / Disaster Team', desc: 'Severe heatwave, dehydration, or temperature hazard' },
  { id: 'medical', name: 'Medical Emergency', emoji: '🏥', team: 'Medical Rescue Team', desc: 'Severe trauma, cardiac distress, or unconscious victim' },
  { id: 'safety', name: 'Safety / Crime', emoji: '🛡️', team: 'Police / Safety Team', desc: 'Violence, assault, or active security hazard' },
  { id: 'other', name: 'Other', emoji: '⚠️', team: 'General Emergency Team', desc: 'Unspecified hazardous or life-threatening situation' }
];

// Initial past emergency history log - empty by default (no fabricated emergencies per Part 11)
const INITIAL_HISTORY = [];

// Express Backend API Base URL
const API_BASE_URL = 'http://localhost:5000';

/**
 * Single reusable email validation rule for Login, Register, and Forgot Password.
 * Validates proper format (e.g. local@domain.tld) and rejects:
 * empty, spaces, missing '@', missing domain, missing TLD, or single-char TLD.
 */
export const isValidEmail = (email) => {
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
};

export default function App() {
  // Authentication session check (User CANNOT bypass auth to enter Home)
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return localStorage.getItem('resqnet_authenticated') === 'true';
  });

  // Screen Navigation:
  // Onboarding screens: 'welcome' | 'onboarding_what_is' | 'onboarding_how_it_works' | 'onboarding_features' | 'auth_choice' | 'login' | 'register'
  // Main authenticated screens: 'home' | 'live_status' | 'history' | 'profile' | 'emergency_details' | 'chat'
  const [currentScreen, setCurrentScreen] = useState(() => {
    const isAuth = localStorage.getItem('resqnet_authenticated') === 'true';
    return isAuth ? 'home' : 'welcome';
  });

  const [activeTab, setActiveTab] = useState('home');

  // Logged-in User State (loaded from localStorage; null if not yet authenticated)
  const [user, setUser] = useState(() => {
    try {
      const saved = localStorage.getItem('resqnet_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  // Login Form States
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [loginError, setLoginError] = useState('');
  const [loginEmailError, setLoginEmailError] = useState('');
  const [showLoginPassword, setShowLoginPassword] = useState(false);
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  // Forgot Password & Reset Password States
  const [forgotPasswordEmail, setForgotPasswordEmail] = useState('');
  const [forgotPasswordError, setForgotPasswordError] = useState('');
  const [forgotPasswordEmailError, setForgotPasswordEmailError] = useState('');
  const [isSendingOtp, setIsSendingOtp] = useState(false);
  const [devOtpHint, setDevOtpHint] = useState('');

  const [resetForm, setResetForm] = useState({
    otp: '',
    newPassword: '',
    confirmNewPassword: ''
  });
  const [resetError, setResetError] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmNewPassword, setShowConfirmNewPassword] = useState(false);
  const [isResettingPassword, setIsResettingPassword] = useState(false);

  // Registration Form States
  const [registerForm, setRegisterForm] = useState({
    name: '',
    phone: '',
    email: '',
    password: '',
    confirmPassword: '',
    bloodGroup: 'O+',
    emergencyContact: ''
  });
  const [registerError, setRegisterError] = useState('');
  const [registerEmailError, setRegisterEmailError] = useState('');
  const [showRegisterPassword, setShowRegisterPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isRegistering, setIsRegistering] = useState(false);

  // Profile Edit State
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [editProfileForm, setEditProfileForm] = useState(() => user || {
    name: '',
    email: '',
    phone: '',
    bloodGroup: 'O+',
    emergencyContact: ''
  });

  // Network Online/Offline Detection
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [offlineQueue, setOfflineQueue] = useState(() => {
    try {
      const saved = localStorage.getItem('resqnet_offline_queue');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // Small success notification / snackbar state
  const [snackbar, setSnackbar] = useState(null);

  // Actual Browser Geolocation Telemetry (No hardcoded coordinates)
  const [gpsLocation, setGpsLocation] = useState({
    latitude: null,
    longitude: null,
    accuracy: null,
    loading: true,
    error: null
  });

  // New Emergency Form State (when selecting a category on Home)
  const [selectedCategory, setSelectedCategory] = useState(EMERGENCY_CATEGORIES[0]);
  const [severity, setSeverity] = useState('Critical');
  const [peopleAffected, setPeopleAffected] = useState(1);
  const [emergencyMessage, setEmergencyMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Active Emergency State (real database-backed emergency)
  const [activeEmergency, setActiveEmergency] = useState(() => {
    try {
      const saved = localStorage.getItem('resqnet_active_emergency');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [cancelModalOpen, setCancelModalOpen] = useState(false);

  // Emergency History State (real emergency history from MongoDB Atlas)
  const [historyList, setHistoryList] = useState(() => {
    try {
      const saved = localStorage.getItem('resqnet_history');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });
  const [selectedHistoryItem, setSelectedHistoryItem] = useState(null);

  // Chat State (Enabled only when an actual responder is assigned)
  const [chatMessages, setChatMessages] = useState([]);
  const [newChatMessage, setNewChatMessage] = useState('');

  // Ref for Leaflet Map on Live Status
  const mapContainerRef = useRef(null);
  const leafletMapRef = useRef(null);

  // Auto-dismiss Snackbar Toast
  useEffect(() => {
    if (snackbar) {
      const timer = setTimeout(() => setSnackbar(null), 5500);
      return () => clearTimeout(timer);
    }
  }, [snackbar]);

  // Auth gate enforcement: User cannot access protected screens without being authenticated
  useEffect(() => {
    const protectedScreens = ['home', 'live_status', 'history', 'profile', 'emergency_details', 'chat'];
    if (!isAuthenticated && protectedScreens.includes(currentScreen)) {
      setCurrentScreen('welcome');
    }
  }, [isAuthenticated, currentScreen]);

  // Geolocation & Network Telemetry Listeners
  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true);
      const queue = JSON.parse(localStorage.getItem('resqnet_offline_queue') || '[]');
      if (queue.length > 0) {
        setSnackbar({
          icon: '🔄',
          title: 'Connection Restored',
          message: `${queue.length} offline emergency request(s) queued for sync.`
        });
      }
    };
    const handleOffline = () => {
      setIsOnline(false);
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Fetch actual GPS coordinates using Browser Geolocation API
    fetchActualGpsLocation();

    // Continuous location tracking via watchPosition
    let watchId = null;
    if (navigator.geolocation) {
      watchId = navigator.geolocation.watchPosition(
        (pos) => {
          setGpsLocation({
            latitude: Number(pos.coords.latitude.toFixed(6)),
            longitude: Number(pos.coords.longitude.toFixed(6)),
            accuracy: Math.round(pos.coords.accuracy),
            loading: false,
            error: null
          });
        },
        (err) => {
          setGpsLocation(prev => {
            if (prev.latitude !== null) return prev;
            return {
              latitude: null,
              longitude: null,
              accuracy: null,
              loading: false,
              error: err.code === 1 ? 'Location permission denied by user.' : 'Unable to acquire GPS coordinates.'
            };
          });
        },
        { enableHighAccuracy: true, timeout: 12000, maximumAge: 10000 }
      );
    }

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      if (watchId !== null && navigator.geolocation) {
        navigator.geolocation.clearWatch(watchId);
      }
    };
  }, []);

  const obtainGpsPosition = () => {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        const err = new Error('Browser does not support Geolocation API.');
        setGpsLocation({
          latitude: null,
          longitude: null,
          accuracy: null,
          loading: false,
          error: err.message
        });
        return reject(err);
      }

      setGpsLocation(prev => ({ ...prev, loading: true, error: null }));

      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const lat = Number(pos.coords.latitude.toFixed(6));
          const lng = Number(pos.coords.longitude.toFixed(6));
          const acc = Math.round(pos.coords.accuracy);
          setGpsLocation({
            latitude: lat,
            longitude: lng,
            accuracy: acc,
            loading: false,
            error: null
          });
          resolve({ latitude: lat, longitude: lng, accuracy: acc });
        },
        (err) => {
          let msg = 'Unable to access your location.';
          if (err.code === 1) {
            msg = 'Unable to access your location. Location permission was denied.';
          } else if (err.code === 2) {
            msg = 'Unable to access your location. GPS position unavailable.';
          } else if (err.code === 3) {
            msg = 'Unable to access your location. GPS acquisition timed out.';
          }
          setGpsLocation({
            latitude: null,
            longitude: null,
            accuracy: null,
            loading: false,
            error: msg
          });
          reject(new Error(msg));
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    });
  };

  const fetchActualGpsLocation = () => {
    obtainGpsPosition().catch(() => {});
  };

  const isGpsAvailable = gpsLocation.latitude !== null && !gpsLocation.error;

  // Leaflet Map Initialization on Live Status (Shows actual victim GPS location, no fake responder)
  useEffect(() => {
    if (currentScreen === 'live_status' && mapContainerRef.current) {
      if (leafletMapRef.current) {
        leafletMapRef.current.remove();
        leafletMapRef.current = null;
      }

      const centerLat = activeEmergency?.latitude ?? gpsLocation.latitude;
      const centerLng = activeEmergency?.longitude ?? gpsLocation.longitude;
      const hasActualCoords = (centerLat !== null && centerLat !== undefined && !isNaN(centerLat)) &&
                              (centerLng !== null && centerLng !== undefined && !isNaN(centerLng));

      if (!hasActualCoords) {
        return;
      }

      const map = L.map(mapContainerRef.current, {
        center: [centerLat, centerLng],
        zoom: 16,
        zoomControl: true
      });

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19
      }).addTo(map);

      const victimIcon = L.divIcon({
        className: 'victim-map-marker-container',
        html: '<div class="victim-pulse-icon" title="Victim Location"></div>',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      });

      const victimMarker = L.marker([centerLat, centerLng], { icon: victimIcon }).addTo(map);
      victimMarker.bindPopup(`<b>🚨 Your Actual Location</b><br>Lat: ${centerLat.toFixed(6)}<br>Lng: ${centerLng.toFixed(6)}<br>Status: SOS Active`).openPopup();

      leafletMapRef.current = map;
    }

    return () => {
      if (leafletMapRef.current) {
        leafletMapRef.current.remove();
        leafletMapRef.current = null;
      }
    };
  }, [currentScreen, activeEmergency, gpsLocation]);

  // Sync real emergency history from MongoDB Atlas for authenticated victim
  useEffect(() => {
    if (isAuthenticated && user && (user.id || user._id)) {
      const userId = user.id || user._id;
      fetch(`${API_BASE_URL}/api/emergencies/user/${userId}`)
        .then(res => res.json())
        .then(data => {
          if (data.success && Array.isArray(data.emergencies)) {
            const formatted = data.emergencies.map(emg => ({
              id: emg.emergency_id,
              emergency_id: emg.emergency_id,
              type: emg.emergency_type,
              emoji: EMERGENCY_CATEGORIES.find(c => c.name === emg.emergency_type)?.emoji || '🚨',
              severity: emg.severity,
              priority: emg.priority,
              peopleAffected: emg.people_affected,
              latitude: emg.latitude,
              longitude: emg.longitude,
              message: emg.message,
              assignedTeam: emg.assigned_team,
              status: emg.status,
              createdAt: new Date(emg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
              date: new Date(emg.created_at).toLocaleDateString([], { day: '2-digit', month: 'short', year: 'numeric' }),
              timestamp: emg.created_at
            }));
            setHistoryList(formatted);
            try {
              localStorage.setItem('resqnet_history', JSON.stringify(formatted));
            } catch (e) {}

            const active = formatted.find(e => e.status !== 'RESOLVED' && e.status !== 'Cancelled');
            if (active && !activeEmergency) {
              setActiveEmergency(active);
              try {
                localStorage.setItem('resqnet_active_emergency', JSON.stringify(active));
              } catch (e) {}
            }
          }
        })
        .catch(err => {
          console.warn('Could not sync emergency history from backend:', err.message);
        });
    }
  }, [isAuthenticated, user]);

  // Route Protection: Prevent unauthorized access to Home / emergency screens
  useEffect(() => {
    const protectedScreens = ['home', 'live_status', 'history', 'profile', 'emergency_details', 'chat'];
    if (!isAuthenticated && protectedScreens.includes(currentScreen)) {
      setCurrentScreen('login');
    }
  }, [isAuthenticated, currentScreen]);

  // Keep editProfileForm synced with user
  useEffect(() => {
    if (user) {
      setEditProfileForm({ ...user });
    }
  }, [user]);

  // Authentication Actions (Connecting to Express + MongoDB Atlas Backend)

  // 1. LOGIN HANDLER
  const handleLogin = async (e) => {
    e.preventDefault();
    setLoginError('');
    setLoginEmailError('');

    const email = loginForm.email ? loginForm.email.trim() : '';
    const password = loginForm.password || '';

    // Validate email format using reusable validation rule before sending request
    if (!isValidEmail(email)) {
      setLoginEmailError('⚠️ Please enter a valid email address.');
      return;
    }

    if (!password) {
      setLoginError('⚠️ Please enter your password.');
      return;
    }

    setIsLoggingIn(true);

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, password })
      });

      const data = await response.json();

      if (!response.ok) {
        setLoginError('⚠️ Incorrect email or password.');
        setIsLoggingIn(false);
        return;
      }

      // Successful authentication: Extract safe user info (NO passwords)
      const authenticatedUser = {
        id: data.user.id || data.user._id,
        name: data.user.name,
        email: data.user.email,
        phone: data.user.phone,
        bloodGroup: data.user.blood_group || data.user.bloodGroup || 'O+',
        emergencyContact: data.user.emergency_contact || data.user.emergencyContact || ''
      };

      // Persist session to localStorage
      localStorage.setItem('resqnet_authenticated', 'true');
      localStorage.setItem('resqnet_user', JSON.stringify(authenticatedUser));

      // Update React state
      setUser(authenticatedUser);
      setIsAuthenticated(true);
      setIsLoggingIn(false);
      setLoginForm({ email: '', password: '' });

      // Notify and navigate to Home
      setSnackbar({
        icon: '✅',
        title: 'Login Successful',
        message: `Welcome back, ${authenticatedUser.name}!`
      });

      setCurrentScreen('home');
      setActiveTab('home');
    } catch (err) {
      console.error('Login network error:', err);
      setLoginError('Unable to connect to ResQNet backend server. Please verify the server is running on port 5000.');
      setIsLoggingIn(false);
    }
  };

  // 2. REGISTRATION HANDLER
  const handleRegister = async (e) => {
    e.preventDefault();
    setRegisterError('');
    setRegisterEmailError('');

    const name = registerForm.name ? registerForm.name.trim() : '';
    const phone = registerForm.phone ? registerForm.phone.trim() : '';
    const email = registerForm.email ? registerForm.email.trim() : '';
    const password = registerForm.password || '';
    const confirmPassword = registerForm.confirmPassword || '';
    const bloodGroup = registerForm.bloodGroup || 'O+';
    const emergencyContact = registerForm.emergencyContact ? registerForm.emergencyContact.trim() : '';

    // Field-level validations
    if (!name || !phone || !email || !password || !confirmPassword || !bloodGroup || !emergencyContact) {
      setRegisterError('All required fields must be filled.');
      return;
    }

    // Email format validation using reusable rule
    if (!isValidEmail(email)) {
      setRegisterEmailError('⚠️ Please enter a valid email address.');
      return;
    }

    const cleanPhone = phone.replace(/[\s-]/g, '');
    if (cleanPhone.length < 7) {
      setRegisterError('Please enter a valid phone number (at least 7 digits).');
      return;
    }

    const cleanEmergency = emergencyContact.replace(/[\s-]/g, '');
    if (cleanEmergency.length < 7) {
      setRegisterError('Please enter a valid emergency contact number.');
      return;
    }

    if (password.length < 6) {
      setRegisterError('Password must have at least 6 characters.');
      return;
    }

    if (password !== confirmPassword) {
      setRegisterError('Passwords do not match.');
      return;
    }

    setIsRegistering(true);

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name,
          phone,
          email,
          password,
          confirm_password: confirmPassword,
          blood_group: bloodGroup,
          emergency_contact: emergencyContact
        })
      });

      const data = await response.json();

      if (!response.ok) {
        if (data.error && data.error.toLowerCase().includes('already exists')) {
          setRegisterEmailError('⚠️ An account with this email already exists.');
          setRegisterError('⚠️ An account with this email already exists.');
        } else {
          setRegisterError(data.error || 'Registration failed. Please try again.');
        }
        setIsRegistering(false);
        return;
      }

      // Backend confirmed successful registration
      setIsRegistering(false);

      // Pre-fill email in login form
      setLoginForm({ email: email, password: '' });

      // Reset register form (passwords never retained)
      setRegisterForm({
        name: '',
        phone: '',
        email: '',
        password: '',
        confirmPassword: '',
        bloodGroup: 'O+',
        emergencyContact: ''
      });

      // Show success notification: "Account created successfully."
      setSnackbar({
        icon: '✅',
        title: 'Account Created',
        message: 'Account created successfully. Please sign in.'
      });

      // Navigate to Login page
      setCurrentScreen('login');
    } catch (err) {
      console.error('Registration network error:', err);
      setRegisterError('Unable to connect to ResQNet backend server. Please verify the server is running on port 5000.');
      setIsRegistering(false);
    }
  };

  // 3. LOGOUT HANDLER
  const handleLogout = () => {
    setIsAuthenticated(false);
    localStorage.removeItem('resqnet_authenticated');
    localStorage.removeItem('resqnet_user');
    setUser(null);
    setLoginForm({ email: '', password: '' });
    setCurrentScreen('login');
    setActiveTab('home');
    setSnackbar({
      icon: '👋',
      title: 'Logged Out',
      message: 'You have been safely signed out.'
    });
  };

  // 4. FORGOT PASSWORD HANDLER (REQUEST 6-DIGIT OTP)
  const handleSendOtp = async (e) => {
    e.preventDefault();
    setForgotPasswordError('');
    setForgotPasswordEmailError('');

    const email = forgotPasswordEmail ? forgotPasswordEmail.trim() : '';

    // Validate email format before sending request
    if (!isValidEmail(email)) {
      setForgotPasswordEmailError('⚠️ Please enter a valid email address.');
      return;
    }

    setIsSendingOtp(true);

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/forgot-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email })
      });

      const data = await response.json();

      if (!response.ok) {
        if (response.status === 404 || (data.error && data.error.toLowerCase().includes('no account'))) {
          const notFoundMsg = '⚠️ No account found with this email address. Please check your email or register a new account.';
          setForgotPasswordEmailError(notFoundMsg);
          setForgotPasswordError(notFoundMsg);
        } else {
          setForgotPasswordError(data.error || 'Unable to process password reset request. Please try again.');
        }
        setIsSendingOtp(false);
        return;
      }

      // Store demo OTP if provided by backend in development mode
      if (data.dev_otp) {
        setDevOtpHint(data.dev_otp);
        setResetForm({ otp: data.dev_otp, newPassword: '', confirmNewPassword: '' });
      } else {
        setDevOtpHint('');
        setResetForm({ otp: '', newPassword: '', confirmNewPassword: '' });
      }

      setResetError('');
      setIsSendingOtp(false);
      setCurrentScreen('reset_password');

      setSnackbar({
        icon: '📨',
        title: 'OTP Sent',
        message: data.message || 'OTP has been sent to your email.'
      });
    } catch (err) {
      console.error('Forgot password network error:', err);
      setForgotPasswordError('Unable to connect to ResQNet backend server.');
      setIsSendingOtp(false);
    }
  };

  // 5. RESET PASSWORD HANDLER (VERIFY OTP & UPDATE PASSWORD)
  const handleResetPassword = async (e) => {
    e.preventDefault();
    setResetError('');

    const otp = resetForm.otp ? resetForm.otp.trim() : '';
    const newPassword = resetForm.newPassword || '';
    const confirmNewPassword = resetForm.confirmNewPassword || '';

    // Validation per prompt requirements
    if (!otp) {
      setResetError('Please enter the OTP.');
      return;
    }

    if (otp.length !== 6) {
      setResetError('Invalid OTP.');
      return;
    }

    if (!newPassword || newPassword.length < 6) {
      setResetError('Password must be at least 6 characters.');
      return;
    }

    if (newPassword !== confirmNewPassword) {
      setResetError('Passwords do not match.');
      return;
    }

    setIsResettingPassword(true);

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/reset-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: forgotPasswordEmail.trim(),
          otp,
          newPassword
        })
      });

      const data = await response.json();

      if (!response.ok) {
        setResetError(data.error || 'Unable to reset password. Please try again.');
        setIsResettingPassword(false);
        return;
      }

      // Reset state and transition to success screen
      setIsResettingPassword(false);
      setResetForm({ otp: '', newPassword: '', confirmNewPassword: '' });
      setDevOtpHint('');
      setCurrentScreen('reset_success');

      setSnackbar({
        icon: '✅',
        title: 'Password Reset',
        message: 'Your password has been updated successfully.'
      });
    } catch (err) {
      console.error('Reset password network error:', err);
      setResetError('Unable to connect to ResQNet backend server.');
      setIsResettingPassword(false);
    }
  };

  // Emergency Dispatch Logic (REAL Backend SOS Flow via POST /api/emergencies)

  // 1. MAIN GRAND SOS BUTTON TRIGGER
  const handleTriggerImmediateSos = async () => {
    if (!isAuthenticated || !user) {
      setCurrentScreen('login');
      setSnackbar({
        icon: '🔒',
        title: 'Authentication Required',
        message: 'Please log in to send an emergency request.'
      });
      return;
    }

    if (activeEmergency) {
      setCurrentScreen('live_status');
      setActiveTab('live_status');
      return;
    }

    // Request fresh device GPS position
    let coords = null;
    try {
      coords = await obtainGpsPosition();
    } catch (err) {
      console.warn('GPS acquisition failed on main SOS:', err.message);
      setSnackbar({
        icon: '⚠️',
        title: 'Location Required',
        message: 'Unable to access your location.',
        actionText: 'Try Again',
        onAction: () => handleTriggerImmediateSos()
      });
      return;
    }

    const userId = user.id || user._id;
    const requestBody = {
      user_id: userId,
      emergency_type: 'Other',
      severity: 'Critical',
      people_affected: 1,
      message: 'Immediate SOS triggered by victim',
      latitude: coords.latitude,
      longitude: coords.longitude,
      location_source: 'gps'
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/emergencies`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();

      if (!response.ok) {
        setSnackbar({
          icon: '⚠️',
          title: 'Emergency Failed',
          message: data.error || 'Failed to dispatch emergency request.'
        });
        return;
      }

      const created = data.emergency;
      const formattedEmergency = {
        id: created.emergency_id,
        emergency_id: created.emergency_id,
        user_id: created.user_id,
        type: created.emergency_type,
        emoji: '🚨',
        severity: created.severity,
        priority: created.priority,
        peopleAffected: created.people_affected,
        people_affected: created.people_affected,
        latitude: created.latitude,
        longitude: created.longitude,
        locationSource: created.location_source,
        message: created.message,
        assignedTeam: created.assigned_team,
        assigned_team: created.assigned_team,
        status: created.status,
        createdAt: new Date(created.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        date: new Date(created.created_at).toLocaleDateString([], { day: '2-digit', month: 'short', year: 'numeric' }),
        timestamp: created.created_at
      };

      // Save returned emergency in React state and localStorage
      setActiveEmergency(formattedEmergency);
      try {
        localStorage.setItem('resqnet_active_emergency', JSON.stringify(formattedEmergency));
      } catch (e) {}

      // Add to emergency history
      setHistoryList(prev => {
        const updated = [formattedEmergency, ...prev.filter(item => (item.emergency_id || item.id) !== formattedEmergency.id)];
        try {
          localStorage.setItem('resqnet_history', JSON.stringify(updated));
        } catch (e) {}
        return updated;
      });

      // Show real confirmation notification (No fake responder assignment)
      setSnackbar({
        icon: '✅',
        title: 'Emergency message sent',
        message: 'Your request has been received by ResQNet.'
      });

      // Navigate to Live Status
      setActiveTab('live_status');
      setCurrentScreen('live_status');
    } catch (err) {
      console.error('SOS dispatch network error:', err);
      setSnackbar({
        icon: '❌',
        title: 'Connection Error',
        message: 'Unable to connect to ResQNet backend server.'
      });
    }
  };

  // 2. CATEGORY EMERGENCY SUBMISSION
  const handleSendCategoryEmergency = async () => {
    if (isSubmitting) return;

    if (!isAuthenticated || !user) {
      setCurrentScreen('login');
      setSnackbar({
        icon: '🔒',
        title: 'Authentication Required',
        message: 'Please log in to send an emergency request.'
      });
      return;
    }

    setIsSubmitting(true);

    // Request fresh device GPS position
    let coords = null;
    try {
      coords = await obtainGpsPosition();
    } catch (err) {
      setIsSubmitting(false);
      console.warn('GPS acquisition failed on category emergency:', err.message);
      setSnackbar({
        icon: '⚠️',
        title: 'Location Required',
        message: 'Unable to access your location.',
        actionText: 'Try Again',
        onAction: () => handleSendCategoryEmergency()
      });
      return;
    }

    const userId = user.id || user._id;
    const requestBody = {
      user_id: userId,
      emergency_type: selectedCategory.name,
      severity: severity,
      people_affected: peopleAffected,
      message: emergencyMessage.trim() || `${selectedCategory.name} reported. Assistance requested.`,
      latitude: coords.latitude,
      longitude: coords.longitude,
      location_source: 'gps'
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/emergencies`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();
      setIsSubmitting(false);

      if (!response.ok) {
        setSnackbar({
          icon: '⚠️',
          title: 'Emergency Failed',
          message: data.error || 'Failed to dispatch emergency request.'
        });
        return;
      }

      const created = data.emergency;
      const formattedEmergency = {
        id: created.emergency_id,
        emergency_id: created.emergency_id,
        user_id: created.user_id,
        type: created.emergency_type,
        emoji: selectedCategory.emoji || '🚨',
        severity: created.severity,
        priority: created.priority,
        peopleAffected: created.people_affected,
        people_affected: created.people_affected,
        latitude: created.latitude,
        longitude: created.longitude,
        locationSource: created.location_source,
        message: created.message,
        assignedTeam: created.assigned_team,
        assigned_team: created.assigned_team,
        status: created.status,
        createdAt: new Date(created.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        date: new Date(created.created_at).toLocaleDateString([], { day: '2-digit', month: 'short', year: 'numeric' }),
        timestamp: created.created_at
      };

      setEmergencyMessage('');

      setActiveEmergency(formattedEmergency);
      try {
        localStorage.setItem('resqnet_active_emergency', JSON.stringify(formattedEmergency));
      } catch (e) {}

      setHistoryList(prev => {
        const updated = [formattedEmergency, ...prev.filter(item => (item.emergency_id || item.id) !== formattedEmergency.id)];
        try {
          localStorage.setItem('resqnet_history', JSON.stringify(updated));
        } catch (e) {}
        return updated;
      });

      setSnackbar({
        icon: '✅',
        title: 'Emergency message sent',
        message: 'Your request has been received by ResQNet.'
      });

      setActiveTab('live_status');
      setCurrentScreen('live_status');
    } catch (err) {
      setIsSubmitting(false);
      console.error('Category SOS network error:', err);
      setSnackbar({
        icon: '❌',
        title: 'Connection Error',
        message: 'Unable to connect to ResQNet backend server.'
      });
    }
  };

  // 3. CANCEL ACTIVE EMERGENCY
  const handleCancelActiveSos = async () => {
    if (!activeEmergency) return;
    const emgId = activeEmergency.emergency_id || activeEmergency.id;

    try {
      await fetch(`${API_BASE_URL}/api/emergencies/${emgId}/cancel`, {
        method: 'PATCH'
      });
    } catch (e) {
      console.warn('Could not notify backend of cancellation:', e.message);
    }

    const cancelledItem = { ...activeEmergency, status: 'Cancelled' };
    setHistoryList(prev => {
      const updated = prev.map(item => (item.id === emgId || item.emergency_id === emgId) ? cancelledItem : item);
      try {
        localStorage.setItem('resqnet_history', JSON.stringify(updated));
      } catch (e) {}
      return updated;
    });

    setActiveEmergency(null);
    try {
      localStorage.removeItem('resqnet_active_emergency');
    } catch (e) {}

    setCancelModalOpen(false);
    setActiveTab('home');
    setCurrentScreen('home');

    setSnackbar({
      icon: 'ℹ️',
      title: 'Emergency Cancelled',
      message: `Emergency #${emgId} has been cancelled.`
    });
  };

  const handleSendChatMessage = (e) => {
    e.preventDefault();
    if (!newChatMessage.trim()) return;

    const messageObj = {
      id: Date.now(),
      sender: 'victim',
      senderName: user ? user.name : 'Victim',
      text: newChatMessage.trim(),
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setChatMessages(prev => [...prev, messageObj]);
    setNewChatMessage('');
  };

  const handleTabChange = (tab) => {
    setActiveTab(tab);
    setCurrentScreen(tab);
  };

  // Bottom navigation visibility: ONLY shown when authenticated and on core screens
  const isNavVisible = isAuthenticated && ['home', 'live_status', 'history', 'profile'].includes(currentScreen);

  // ==========================================================================
  // RENDER UI
  // ==========================================================================
  return (
    <div className={`app-wrapper ${!isNavVisible ? 'no-bottom-nav' : ''}`}>
      {/* Top Header Bar (Shown once authenticated) */}
      {isNavVisible && (
        <header className="top-header">
          <div className="header-left">
            <span className="header-logo">
              <span className="beacon-icon">🚨</span> ResQNet
            </span>
          </div>
          <div className="header-right">
            {/* GPS Telemetry Pill */}
            <div className={`status-pill ${isGpsAvailable ? 'gps-active' : 'gps-pending'}`}>
              <span className="status-dot" style={{ backgroundColor: isGpsAvailable ? '#1D4ED8' : '#B45309' }}></span>
              {isGpsAvailable ? 'GPS Active' : (gpsLocation.loading ? 'GPS Acquiring' : 'GPS Unavailable')}
            </div>

            {/* Internet Status Pill */}
            <div className={`status-pill ${isOnline ? 'online' : 'offline'}`}>
              <span className="status-dot"></span>
              {isOnline ? 'Online' : 'Offline'}
            </div>
          </div>
        </header>
      )}

      {/* Snackbar / Toast Notification */}
      {snackbar && (
        <div className="snackbar-toast">
          <div className="toast-icon">{snackbar.icon}</div>
          <div className="toast-content">
            <div className="toast-title">{snackbar.title}</div>
            <div className="toast-body">{snackbar.message}</div>
            {snackbar.actionText && (
              <button
                type="button"
                className="toast-action-btn"
                onClick={() => {
                  const act = snackbar.onAction;
                  setSnackbar(null);
                  if (act) act();
                }}
                style={{
                  marginTop: '6px',
                  background: 'white',
                  color: '#DC2626',
                  border: 'none',
                  padding: '4px 10px',
                  borderRadius: '4px',
                  fontWeight: '700',
                  fontSize: '0.8rem',
                  cursor: 'pointer',
                  display: 'inline-block'
                }}
              >
                {snackbar.actionText}
              </button>
            )}
          </div>
          <button className="toast-close-btn" onClick={() => setSnackbar(null)}>✕</button>
        </div>
      )}

      {/* Distinct Offline Alert Banners */}
      {!isOnline && isGpsAvailable && (
        <div className="offline-banner">
          <span className="banner-icon">🔴</span>
          <div className="banner-text">
            <b>Offline — GPS Available</b>: SOS saved on this device. It will be sent when connectivity returns.
          </div>
          {offlineQueue.length > 0 && (
            <span className="queue-count">{offlineQueue.length} queued</span>
          )}
        </div>
      )}

      {!isOnline && !isGpsAvailable && (
        <div className="offline-banner">
          <span className="banner-icon">🔴</span>
          <div className="banner-text">
            <b>Offline — GPS Unavailable</b>: Please enable location permission. Requests will be stored locally.
          </div>
        </div>
      )}

      {/* ======================================================================
          ONBOARDING 1: WELCOME SCREEN
          ====================================================================== */}
      {currentScreen === 'welcome' && (
        <div className="splash-screen">
          <div className="splash-hero">
            <div className="splash-icon-wrapper">🚨</div>
            <h1 className="splash-title">ResQNet</h1>
            <p className="splash-tagline">Emergency Assistance Network</p>
            <p className="splash-desc">
              Get help quickly when you need it most. Location-aware distress signaling and automated rescue team routing.
            </p>
          </div>
          <div className="splash-actions">
            <button className="btn btn-primary btn-block" onClick={() => setCurrentScreen('onboarding_what_is')}>
              Get Started →
            </button>
            <button
              className="onboarding-skip-btn"
              onClick={() => setCurrentScreen('login')}
            >
              Already registered? Sign In
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          ONBOARDING 2: WHAT IS RESQNET?
          ====================================================================== */}
      {currentScreen === 'onboarding_what_is' && (
        <div className="onboarding-screen">
          <div className="onboarding-top-nav">
            <span className="onboarding-step-counter">Step 1 of 3</span>
            <div className="onboarding-dots">
              <span className="onboarding-dot active"></span>
              <span className="onboarding-dot"></span>
              <span className="onboarding-dot"></span>
            </div>
            <button className="onboarding-skip-btn" onClick={() => setCurrentScreen('login')}>
              Skip to Login
            </button>
          </div>

          <div className="onboarding-content-body">
            <h2 className="onboarding-hero-title">What is ResQNet?</h2>
            <p className="onboarding-hero-desc">
              ResQNet is a location-aware emergency assistance platform that helps victims raise emergencies and connects them with the appropriate rescue teams.
            </p>

            <div className="pillar-card-list">
              <div className="pillar-card">
                <div className="pillar-icon-box">📍</div>
                <div>
                  <div className="pillar-title">Location Aware</div>
                  <div className="pillar-desc">
                    Automatically detects your device's exact GPS coordinates so emergency responders find you without delay.
                  </div>
                </div>
              </div>

              <div className="pillar-card">
                <div className="pillar-icon-box">🚨</div>
                <div>
                  <div className="pillar-title">One-Tap SOS</div>
                  <div className="pillar-desc">
                    Trigger an immediate, high-priority distress beacon instantly during life-threatening danger.
                  </div>
                </div>
              </div>

              <div className="pillar-card">
                <div className="pillar-icon-box">🤝</div>
                <div>
                  <div className="pillar-title">Connected Rescue</div>
                  <div className="pillar-desc">
                    Bridges victims with verified response forces — including flood squads, fire rescue, and medical teams.
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="onboarding-bottom-actions">
            <button className="btn btn-outline" style={{ flex: 1 }} onClick={() => setCurrentScreen('welcome')}>
              ← Back
            </button>
            <button className="btn btn-primary" style={{ flex: 2 }} onClick={() => setCurrentScreen('onboarding_how_it_works')}>
              Next →
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          ONBOARDING 3: HOW RESQNET HELPS (HOW IT WORKS)
          ====================================================================== */}
      {currentScreen === 'onboarding_how_it_works' && (
        <div className="onboarding-screen">
          <div className="onboarding-top-nav">
            <span className="onboarding-step-counter">Step 2 of 3</span>
            <div className="onboarding-dots">
              <span className="onboarding-dot"></span>
              <span className="onboarding-dot active"></span>
              <span className="onboarding-dot"></span>
            </div>
            <button className="onboarding-skip-btn" onClick={() => setCurrentScreen('login')}>
              Skip to Login
            </button>
          </div>

          <div className="onboarding-content-body">
            <h2 className="onboarding-hero-title">How ResQNet Helps</h2>
            <p className="onboarding-hero-desc">
              From distress trigger to on-site rescue, every step is coordinated automatically.
            </p>

            <div className="flow-sequence">
              <div className="flow-step-item">
                <div className="flow-step-badge">🚨</div>
                <div className="flow-step-info">
                  <div className="flow-step-name">Raise SOS</div>
                  <div className="flow-step-sub">Victim triggers distress via immediate SOS or disaster category</div>
                </div>
              </div>
              <div className="flow-arrow-down">▼</div>

              <div className="flow-step-item">
                <div className="flow-step-badge">📍</div>
                <div className="flow-step-info">
                  <div className="flow-step-name">Location Detected</div>
                  <div className="flow-step-sub">Browser Geolocation API locks exact live GPS coordinates</div>
                </div>
              </div>
              <div className="flow-arrow-down">▼</div>

              <div className="flow-step-item">
                <div className="flow-step-badge">🧠</div>
                <div className="flow-step-info">
                  <div className="flow-step-name">Emergency Routed</div>
                  <div className="flow-step-sub">Intelligent backend routing identifies the required specialized unit</div>
                </div>
              </div>
              <div className="flow-arrow-down">▼</div>

              <div className="flow-step-item">
                <div className="flow-step-badge">🚑</div>
                <div className="flow-step-info">
                  <div className="flow-step-name">Responder Assigned</div>
                  <div className="flow-step-sub">Nearest response team accepts dispatch and heads to coordinates</div>
                </div>
              </div>
              <div className="flow-arrow-down">▼</div>

              <div className="flow-step-item">
                <div className="flow-step-badge">💬</div>
                <div className="flow-step-info">
                  <div className="flow-step-name">Track & Communicate</div>
                  <div className="flow-step-sub">Follow unit on live map and chat directly with assigned responder</div>
                </div>
              </div>
            </div>

            {/* Core Principle Callout Box */}
            <div className="principle-callout">
              <span className="principle-icon">📢</span>
              <div>
                <div className="principle-title">Core ResQNet Rule</div>
                <div className="principle-quote">
                  “You don't choose the responder. ResQNet routes your emergency to the appropriate team.”
                </div>
                <div className="principle-sub">
                  Victims focus solely on staying safe; the platform assigns the right specialized responders automatically.
                </div>
              </div>
            </div>
          </div>

          <div className="onboarding-bottom-actions">
            <button className="btn btn-outline" style={{ flex: 1 }} onClick={() => setCurrentScreen('onboarding_what_is')}>
              ← Back
            </button>
            <button className="btn btn-primary" style={{ flex: 2 }} onClick={() => setCurrentScreen('onboarding_features')}>
              Next →
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          ONBOARDING 4: FEATURES SCREEN
          ====================================================================== */}
      {currentScreen === 'onboarding_features' && (
        <div className="onboarding-screen">
          <div className="onboarding-top-nav">
            <span className="onboarding-step-counter">Step 3 of 3</span>
            <div className="onboarding-dots">
              <span className="onboarding-dot"></span>
              <span className="onboarding-dot"></span>
              <span className="onboarding-dot active"></span>
            </div>
            <button className="onboarding-skip-btn" onClick={() => setCurrentScreen('login')}>
              Skip to Login
            </button>
          </div>

          <div className="onboarding-content-body">
            <h2 className="onboarding-hero-title">Features</h2>
            <p className="onboarding-hero-desc">
              Comprehensive disaster tools engineered for emergency response and resilience.
            </p>

            <div className="features-grid-onboarding">
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🌊</span>
                <span className="feature-pill-text">Natural Disaster Assistance</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🔥</span>
                <span className="feature-pill-text">Fire Emergency</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🏥</span>
                <span className="feature-pill-text">Medical Emergency</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🛡️</span>
                <span className="feature-pill-text">Safety Assistance</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">📍</span>
                <span className="feature-pill-text">Live GPS Location</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🗺️</span>
                <span className="feature-pill-text">Emergency Map</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">💬</span>
                <span className="feature-pill-text">Responder Communication</span>
              </div>
              <div className="feature-pill-card">
                <span className="feature-pill-icon">🔴</span>
                <span className="feature-pill-text">Offline SOS</span>
              </div>
            </div>
          </div>

          <div className="onboarding-bottom-actions">
            <button className="btn btn-outline" style={{ flex: 1 }} onClick={() => setCurrentScreen('onboarding_how_it_works')}>
              ← Back
            </button>
            <button className="btn btn-primary" style={{ flex: 2 }} onClick={() => setCurrentScreen('login')}>
              Continue to Login →
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          ONBOARDING 5: AUTHENTICATION CHOICE SCREEN
          ====================================================================== */}
      {currentScreen === 'auth_choice' && (
        <div className="screen-container" style={{ justifyContent: 'center', minHeight: '100vh', gap: '24px' }}>
          <div style={{ textAlign: 'center' }}>
            <div className="splash-icon-wrapper" style={{ margin: '0 auto 16px' }}>🚨</div>
            <h2 className="screen-title" style={{ fontSize: '1.6rem' }}>Access ResQNet</h2>
            <p className="screen-subtitle">Sign in or register to connect with emergency response</p>
          </div>

          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '14px', padding: '24px 20px' }}>
            <button className="btn btn-primary btn-block" onClick={() => setCurrentScreen('login')}>
              Sign In to Account
            </button>
            <button className="btn btn-outline btn-block" onClick={() => setCurrentScreen('register')}>
              Create New Account
            </button>

            <div style={{ position: 'relative', textAlign: 'center', margin: '6px 0' }}>
              <div style={{ height: '1px', background: 'var(--border)' }}></div>
              <span style={{ position: 'absolute', top: '-10px', left: '50%', transform: 'translateX(-50%)', background: 'white', padding: '0 10px', fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                EVALUATION DEMO
              </span>
            </div>

            <button
              type="button"
              className="btn btn-outline btn-block btn-sm"
              style={{ backgroundColor: '#FEF2F2', borderColor: '#FECACA', color: 'var(--primary-dark)', fontWeight: '700' }}
              onClick={handleQuickDemoLogin}
            >
              ⚡ Instant Demo Sign In
            </button>
          </div>

          <div style={{ textAlign: 'center' }}>
            <button
              className="onboarding-skip-btn"
              onClick={() => setCurrentScreen('onboarding_features')}
            >
              ← Back to Features
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          LOGIN SCREEN
          ====================================================================== */}
      {currentScreen === 'login' && (
        <div className="screen-container">
          <button className="back-btn" onClick={() => setCurrentScreen('onboarding_features')}>
            ← Back to Features
          </button>
          <div>
            <h2 className="screen-title">Welcome Back</h2>
            <p className="screen-subtitle">Sign in to access your emergency assistance.</p>
          </div>

          <div className="card">
            <form onSubmit={handleLogin} noValidate style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {loginError && (
                <div className="auth-alert-error">
                  <span className="alert-icon">⚠️</span>
                  <div>{loginError}</div>
                </div>
              )}
              <div className="form-group">
                <label className="form-label">Email</label>
                <input
                  type="email"
                  className={`form-input ${loginEmailError ? 'has-error' : ''}`}
                  placeholder="name@example.com"
                  value={loginForm.email}
                  onChange={(e) => {
                    const val = e.target.value;
                    setLoginForm({ ...loginForm, email: val });
                    if (loginEmailError && isValidEmail(val)) {
                      setLoginEmailError('');
                    }
                    if (loginError) setLoginError('');
                  }}
                  autoComplete="email"
                />
                {loginEmailError && (
                  <div className="auth-field-error">
                    {loginEmailError}
                  </div>
                )}
              </div>

              <div className="form-group">
                <label className="form-label">Password</label>
                <div className="password-input-wrapper">
                  <input
                    type={showLoginPassword ? 'text' : 'password'}
                    className="form-input"
                    placeholder="Enter your password"
                    value={loginForm.password}
                    onChange={(e) => {
                      setLoginForm({ ...loginForm, password: e.target.value });
                      if (loginError) setLoginError('');
                    }}
                    autoComplete="current-password"
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={() => setShowLoginPassword(!showLoginPassword)}
                    title={showLoginPassword ? 'Hide password' : 'Show password'}
                    aria-label="Toggle password visibility"
                  >
                    {showLoginPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '-4px' }}>
                <button
                  type="button"
                  className="auth-forgot-link"
                  onClick={() => {
                    setLoginError('');
                    setLoginEmailError('');
                    setForgotPasswordEmail(loginForm.email || '');
                    setForgotPasswordError('');
                    setForgotPasswordEmailError('');
                    setDevOtpHint('');
                    setCurrentScreen('forgot_password');
                  }}
                >
                  Forgot Password?
                </button>
              </div>

              <button
                type="submit"
                className="btn btn-primary btn-block"
                style={{ marginTop: '8px' }}
                disabled={isLoggingIn}
              >
                {isLoggingIn ? (
                  <>
                    <span className="btn-spinner"></span>
                    Signing In...
                  </>
                ) : (
                  'Login'
                )}
              </button>
            </form>
          </div>

          <div className="auth-redirect-box">
            Don't have an account?{' '}
            <button
              type="button"
              className="auth-switch-link"
              onClick={() => {
                setLoginError('');
                setLoginEmailError('');
                setRegisterError('');
                setRegisterEmailError('');
                setCurrentScreen('register');
              }}
            >
              Create Account
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          REGISTRATION SCREEN
          ====================================================================== */}
      {currentScreen === 'register' && (
        <div className="screen-container">
          <button
            className="back-btn"
            onClick={() => {
              setRegisterError('');
              setRegisterEmailError('');
              setLoginEmailError('');
              setCurrentScreen('login');
            }}
          >
            ← Back to Login
          </button>
          <div>
            <h2 className="screen-title">Create Your ResQNet Account</h2>
            <p className="screen-subtitle">Register to access emergency assistance quickly.</p>
          </div>

          <div className="card">
            <form onSubmit={handleRegister} noValidate style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {registerError && (
                <div className="auth-alert-error">
                  <span className="alert-icon">⚠️</span>
                  <div>{registerError}</div>
                </div>
              )}
              <div className="form-group">
                <label className="form-label">Full Name</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="e.g. Rahul Sharma"
                  value={registerForm.name}
                  onChange={(e) => {
                    setRegisterForm({ ...registerForm, name: e.target.value });
                    if (registerError) setRegisterError('');
                  }}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Phone Number</label>
                <input
                  type="tel"
                  className="form-input"
                  placeholder="e.g. +91 98765 43210"
                  value={registerForm.phone}
                  onChange={(e) => {
                    setRegisterForm({ ...registerForm, phone: e.target.value });
                    if (registerError) setRegisterError('');
                  }}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Email Address</label>
                <input
                  type="email"
                  className={`form-input ${registerEmailError ? 'has-error' : ''}`}
                  placeholder="name@example.com"
                  value={registerForm.email}
                  onChange={(e) => {
                    const val = e.target.value;
                    setRegisterForm({ ...registerForm, email: val });
                    if (registerEmailError && isValidEmail(val)) {
                      setRegisterEmailError('');
                    }
                    if (registerError) setRegisterError('');
                  }}
                  autoComplete="email"
                />
                {registerEmailError && (
                  <div className="auth-field-error">
                    {registerEmailError}
                  </div>
                )}
              </div>

              <div className="form-group">
                <label className="form-label">
                  Password
                  <span className="form-label-hint">Min 6 characters</span>
                </label>
                <div className="password-input-wrapper">
                  <input
                    type={showRegisterPassword ? 'text' : 'password'}
                    className="form-input"
                    placeholder="Create a password (min 6 chars)"
                    value={registerForm.password}
                    onChange={(e) => {
                      setRegisterForm({ ...registerForm, password: e.target.value });
                      if (registerError) setRegisterError('');
                    }}
                    autoComplete="new-password"
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={() => setShowRegisterPassword(!showRegisterPassword)}
                    title={showRegisterPassword ? 'Hide password' : 'Show password'}
                    aria-label="Toggle password visibility"
                  >
                    {showRegisterPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Confirm Password</label>
                <div className="password-input-wrapper">
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    className="form-input"
                    placeholder="Confirm your password"
                    value={registerForm.confirmPassword}
                    onChange={(e) => {
                      setRegisterForm({ ...registerForm, confirmPassword: e.target.value });
                      if (registerError) setRegisterError('');
                    }}
                    autoComplete="new-password"
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    title={showConfirmPassword ? 'Hide password' : 'Show password'}
                    aria-label="Toggle confirm password visibility"
                  >
                    {showConfirmPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Blood Group</label>
                <select
                  className="form-select"
                  value={registerForm.bloodGroup}
                  onChange={(e) => setRegisterForm({ ...registerForm, bloodGroup: e.target.value })}
                  required
                >
                  {['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map(bg => (
                    <option key={bg} value={bg}>{bg}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">
                  Emergency Contact Number
                  <span className="form-label-hint">Family or close contact</span>
                </label>
                <input
                  type="tel"
                  className="form-input"
                  placeholder="e.g. +91 98765 00000"
                  value={registerForm.emergencyContact}
                  onChange={(e) => {
                    setRegisterForm({ ...registerForm, emergencyContact: e.target.value });
                    if (registerError) setRegisterError('');
                  }}
                  required
                />
              </div>

              <button
                type="submit"
                className="btn btn-primary btn-block"
                style={{ marginTop: '10px' }}
                disabled={isRegistering}
              >
                {isRegistering ? (
                  <>
                    <span className="btn-spinner"></span>
                    Creating Account...
                  </>
                ) : (
                  'Create Account'
                )}
              </button>
            </form>
          </div>

          <div className="auth-redirect-box">
            Already have an account?{' '}
            <button
              type="button"
              className="auth-switch-link"
              onClick={() => {
                setRegisterError('');
                setRegisterEmailError('');
                setLoginEmailError('');
                setCurrentScreen('login');
              }}
            >
              Login
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          FORGOT PASSWORD SCREEN
          ====================================================================== */}
      {currentScreen === 'forgot_password' && (
        <div className="screen-container">
          <button
            type="button"
            className="back-btn"
            onClick={() => {
              setForgotPasswordError('');
              setForgotPasswordEmailError('');
              setLoginEmailError('');
              setCurrentScreen('login');
            }}
          >
            ← Back to Login
          </button>
          <div>
            <h2 className="screen-title">Forgot Password?</h2>
            <p className="screen-subtitle">Enter your registered email address to reset your password.</p>
          </div>

          <div className="card">
            <form onSubmit={handleSendOtp} noValidate style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {forgotPasswordError && (
                <div className="auth-alert-error">
                  <span className="alert-icon">⚠️</span>
                  <div>{forgotPasswordError}</div>
                </div>
              )}

              <div className="form-group">
                <label className="form-label">Email Address</label>
                <input
                  type="email"
                  className={`form-input ${forgotPasswordEmailError ? 'has-error' : ''}`}
                  placeholder="name@example.com"
                  value={forgotPasswordEmail}
                  onChange={(e) => {
                    const val = e.target.value;
                    setForgotPasswordEmail(val);
                    if (forgotPasswordEmailError && isValidEmail(val)) {
                      setForgotPasswordEmailError('');
                    }
                    if (forgotPasswordError) setForgotPasswordError('');
                  }}
                  autoComplete="email"
                />
                {forgotPasswordEmailError && (
                  <div className="auth-field-error">
                    {forgotPasswordEmailError}
                  </div>
                )}
              </div>

              <button
                type="submit"
                className="btn btn-primary btn-block"
                style={{ marginTop: '8px' }}
                disabled={isSendingOtp}
              >
                {isSendingOtp ? (
                  <>
                    <span className="btn-spinner"></span>
                    Sending OTP...
                  </>
                ) : (
                  'Send OTP'
                )}
              </button>
            </form>
          </div>

          <div className="auth-redirect-box">
            Remember your password?{' '}
            <button
              type="button"
              className="auth-switch-link"
              onClick={() => {
                setForgotPasswordError('');
                setForgotPasswordEmailError('');
                setLoginEmailError('');
                setCurrentScreen('login');
              }}
            >
              Back to Login
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          RESET PASSWORD SCREEN (OTP VERIFICATION + NEW PASSWORD)
          ====================================================================== */}
      {currentScreen === 'reset_password' && (
        <div className="screen-container">
          <button
            type="button"
            className="back-btn"
            onClick={() => {
              setResetError('');
              setCurrentScreen('login');
            }}
          >
            ← Back to Login
          </button>
          <div>
            <h2 className="screen-title">Reset Password</h2>
            <p className="screen-subtitle">
              Enter the OTP sent to <strong>{forgotPasswordEmail}</strong> and your new password.
            </p>
          </div>

          {devOtpHint && (
            <div className="dev-otp-banner">
              <div>
                <span style={{ fontWeight: 600 }}>Demo OTP: </span>
                <code>{devOtpHint}</code>
                <span style={{ display: 'block', fontSize: '0.76rem', color: '#3B82F6', marginTop: '2px' }}>
                  (Expires in 5 minutes)
                </span>
              </div>
              <button
                type="button"
                className="btn btn-sm btn-secondary"
                style={{ fontSize: '0.78rem', padding: '4px 8px' }}
                onClick={() => setResetForm(prev => ({ ...prev, otp: devOtpHint }))}
              >
                Auto-fill
              </button>
            </div>
          )}

          <div className="card">
            <form onSubmit={handleResetPassword} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {resetError && (
                <div className="auth-alert-error">
                  <span className="alert-icon">⚠️</span>
                  <div>{resetError}</div>
                </div>
              )}

              <div className="form-group">
                <label className="form-label">Enter OTP</label>
                <input
                  type="text"
                  maxLength={6}
                  className="form-input"
                  placeholder="6-digit OTP"
                  value={resetForm.otp}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                    setResetForm({ ...resetForm, otp: val });
                    if (resetError) setResetError('');
                  }}
                  required
                  style={{ letterSpacing: '4px', fontSize: '1.1rem', fontWeight: '600', textAlign: 'center' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">New Password</label>
                <div className="password-input-wrapper">
                  <input
                    type={showNewPassword ? 'text' : 'password'}
                    className="form-input"
                    placeholder="At least 6 characters"
                    value={resetForm.newPassword}
                    onChange={(e) => {
                      setResetForm({ ...resetForm, newPassword: e.target.value });
                      if (resetError) setResetError('');
                    }}
                    autoComplete="new-password"
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={() => setShowNewPassword(!showNewPassword)}
                    title={showNewPassword ? 'Hide password' : 'Show password'}
                    aria-label="Toggle password visibility"
                  >
                    {showNewPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Confirm New Password</label>
                <div className="password-input-wrapper">
                  <input
                    type={showConfirmNewPassword ? 'text' : 'password'}
                    className="form-input"
                    placeholder="Confirm new password"
                    value={resetForm.confirmNewPassword}
                    onChange={(e) => {
                      setResetForm({ ...resetForm, confirmNewPassword: e.target.value });
                      if (resetError) setResetError('');
                    }}
                    autoComplete="new-password"
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle-btn"
                    onClick={() => setShowConfirmNewPassword(!showConfirmNewPassword)}
                    title={showConfirmNewPassword ? 'Hide password' : 'Show password'}
                    aria-label="Toggle password visibility"
                  >
                    {showConfirmNewPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>

              <button
                type="submit"
                className="btn btn-primary btn-block"
                style={{ marginTop: '8px' }}
                disabled={isResettingPassword}
              >
                {isResettingPassword ? (
                  <>
                    <span className="btn-spinner"></span>
                    Resetting Password...
                  </>
                ) : (
                  'Reset Password'
                )}
              </button>
            </form>
          </div>

          <div className="auth-redirect-box">
            <button
              type="button"
              className="auth-switch-link"
              onClick={() => {
                setResetError('');
                setCurrentScreen('login');
              }}
            >
              ← Back to Login
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          PASSWORD RESET SUCCESSFUL SCREEN
          ====================================================================== */}
      {currentScreen === 'reset_success' && (
        <div className="screen-container" style={{ textAlign: 'center', justifyContent: 'center', padding: '32px 16px' }}>
          <div className="card reset-success-card">
            <div className="reset-success-icon">
              ✓
            </div>

            <h2 className="screen-title" style={{ margin: 0 }}>Password Reset Successful</h2>
            <p className="screen-subtitle" style={{ fontSize: '0.95rem', maxWidth: '340px' }}>
              Your password has been updated successfully.
            </p>

            <button
              type="button"
              className="btn btn-primary btn-block"
              style={{ marginTop: '12px' }}
              onClick={() => {
                setLoginForm({ email: forgotPasswordEmail, password: '' });
                setLoginError('');
                setResetError('');
                setForgotPasswordError('');
                setCurrentScreen('login');
              }}
            >
              Go to Login
            </button>
          </div>
        </div>
      )}

      {/* ======================================================================
          SCREEN 4: HOME SCREEN (Create Emergency) - AUTHENTICATED ONLY
          ====================================================================== */}
      {currentScreen === 'home' && isAuthenticated && (
        <div className="screen-container">
          <div className="home-greeting-card">
            <div>
              <h2 className="greeting-name">Hello, {user?.name || 'Citizen'}</h2>
              <div className="greeting-location-status">
                <span>📍</span> {isGpsAvailable ? 'Location sharing active' : 'GPS acquiring...'}
              </div>
            </div>
            <div style={{ textAlign: 'right', fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
              {isGpsAvailable ? (
                <>GPS: {gpsLocation.latitude.toFixed(4)}, {gpsLocation.longitude.toFixed(4)}</>
              ) : (
                <button
                  onClick={fetchActualGpsLocation}
                  style={{ background: 'none', border: 'none', color: 'var(--primary)', cursor: 'pointer', textDecoration: 'underline', fontSize: '0.75rem' }}
                >
                  Enable GPS
                </button>
              )}
            </div>
          </div>

          {activeEmergency && (
            <div
              className="active-sos-alert-banner"
              onClick={() => {
                setActiveTab('live_status');
                setCurrentScreen('live_status');
              }}
            >
              <div className="active-sos-banner-left">
                <span style={{ fontSize: '1.8rem' }}>{activeEmergency.emoji}</span>
                <div>
                  <div className="active-sos-banner-title">Active Emergency in Progress</div>
                  <div className="active-sos-banner-subtitle">{activeEmergency.type} ({activeEmergency.priority})</div>
                </div>
              </div>
              <button className="active-sos-view-btn">Live Status →</button>
            </div>
          )}

          {/* Grand SOS Button */}
          <div className="sos-section">
            <span className="sos-label-top">In an Emergency?</span>
            <div className="sos-button-wrapper">
              <div className="sos-pulse-ring"></div>
              <div className="sos-pulse-ring"></div>
              <button className="big-sos-btn" onClick={handleTriggerImmediateSos}>
                <span className="big-sos-icon">🚨</span>
                <span className="big-sos-text">SOS</span>
                <span className="big-sos-sub">Immediate Help</span>
              </button>
            </div>
            <p className="sos-help-text">Press for immediate emergency assistance</p>
          </div>

          {/* 10 Disaster Emergency Categories on Home */}
          <div className="emergency-grid-section">
            <div className="section-header-row">
              <h3 className="section-title">
                <span>⚡</span> Emergency SOS
              </h3>
              <span className="section-badge">11 Categories</span>
            </div>

            <div className="emergency-grid">
              {EMERGENCY_CATEGORIES.map((cat) => (
                <div
                  key={cat.id}
                  className="emergency-cat-card"
                  onClick={() => {
                    setSelectedCategory(cat);
                    setCurrentScreen('emergency_details');
                  }}
                >
                  <div className="cat-emoji-bubble">{cat.emoji}</div>
                  <div className="cat-info">
                    <div className="cat-name">{cat.name}</div>
                    <div className="cat-routing">{cat.team}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ======================================================================
          SCREEN 5: EMERGENCY DETAILS SCREEN
          ====================================================================== */}
      {currentScreen === 'emergency_details' && isAuthenticated && (
        <div className="screen-container">
          <button className="back-btn" onClick={() => setCurrentScreen('home')}>
            ← Back to Home
          </button>

          <div className="selected-cat-banner">
            <span className="selected-cat-emoji">{selectedCategory.emoji}</span>
            <div>
              <div className="selected-cat-name">{selectedCategory.name}</div>
              <div className="selected-cat-team">Target Unit: {selectedCategory.team}</div>
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">
              Severity Level
              <span className="form-label-hint">Determines dispatch priority</span>
            </label>
            <div className="severity-selector">
              {['Low', 'Medium', 'High', 'Critical'].map((level) => (
                <button
                  key={level}
                  type="button"
                  className={`severity-btn ${level.toLowerCase()} ${severity === level ? 'active' : ''}`}
                  onClick={() => setSeverity(level)}
                >
                  {level}
                </button>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">People Affected</label>
            <div className="counter-box">
              <button
                type="button"
                className="counter-btn"
                onClick={() => setPeopleAffected(Math.max(1, peopleAffected - 1))}
              >
                −
              </button>
              <span className="counter-value">{peopleAffected}</span>
              <button
                type="button"
                className="counter-btn"
                onClick={() => setPeopleAffected(peopleAffected + 1)}
              >
                +
              </button>
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">
              Additional Details (Optional)
              <span className="form-label-hint">e.g. Water level rising, trapped floor</span>
            </label>
            <textarea
              className="form-textarea"
              placeholder="Describe current danger, landmarks, or special medical needs..."
              value={emergencyMessage}
              onChange={(e) => setEmergencyMessage(e.target.value)}
            />
          </div>

          <div className="location-status-card">
            <div className={`location-icon-wrapper ${!isGpsAvailable ? 'warning' : ''}`}>
              {!isGpsAvailable ? '⚠️' : '📍'}
            </div>
            <div style={{ flex: 1 }}>
              <div className="location-info-title">
                {isGpsAvailable ? 'Location Detected via Geolocation API' : 'GPS Location Pending'}
              </div>
              <div className="location-coords">
                {isGpsAvailable ? (
                  `Latitude: ${gpsLocation.latitude.toFixed(6)}, Longitude: ${gpsLocation.longitude.toFixed(6)} (±${gpsLocation.accuracy}m)`
                ) : (
                  gpsLocation.error || 'Acquiring device GPS coordinates...'
                )}
              </div>
              <button type="button" className="location-retry-btn" onClick={fetchActualGpsLocation}>
                {gpsLocation.loading ? 'Acquiring GPS...' : 'Refresh GPS Coordinates'}
              </button>
            </div>
          </div>

          <button
            className="btn btn-primary btn-block"
            style={{ padding: '16px', fontSize: '1.05rem', marginTop: '4px' }}
            disabled={isSubmitting}
            onClick={handleSendCategoryEmergency}
          >
            {isSubmitting ? 'Sending Emergency...' : '🚨 SEND EMERGENCY'}
          </button>
        </div>
      )}

      {/* ======================================================================
          SCREEN 6: LIVE STATUS SCREEN (Monitor Emergency)
          ====================================================================== */}
      {currentScreen === 'live_status' && isAuthenticated && (
        <div className="screen-container">
          {activeEmergency ? (
            <>
              <div className="active-sos-hero">
                <div className="active-sos-header-row">
                  <span className="active-badge-pulsing">
                    <span className="status-dot" style={{ backgroundColor: '#EF4444' }}></span>
                    ACTIVE EMERGENCY
                  </span>
                  <span className="priority-tag">Priority: {activeEmergency.priority}</span>
                </div>

                <h2 className="active-sos-incident-title">
                  <span>{activeEmergency.emoji || '🚨'}</span>
                  {activeEmergency.type}
                </h2>

                <div className="active-sos-meta-grid">
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">Emergency ID</span>
                    <span className="active-sos-meta-value">{activeEmergency.emergency_id || activeEmergency.id}</span>
                  </div>
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">Emergency Type</span>
                    <span className="active-sos-meta-value">{activeEmergency.type}</span>
                  </div>
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">Severity</span>
                    <span className="active-sos-meta-value">{activeEmergency.severity}</span>
                  </div>
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">People Affected</span>
                    <span className="active-sos-meta-value">{activeEmergency.peopleAffected || activeEmergency.people_affected || 1}</span>
                  </div>
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">Assigned Team</span>
                    <span className="active-sos-meta-value">{activeEmergency.assignedTeam || activeEmergency.assigned_team}</span>
                  </div>
                  <div className="active-sos-meta-item">
                    <span className="active-sos-meta-label">GPS Coordinates</span>
                    <span className="active-sos-meta-value">
                      {activeEmergency.latitude != null && activeEmergency.longitude != null
                        ? `${Number(activeEmergency.latitude).toFixed(6)}, ${Number(activeEmergency.longitude).toFixed(6)}`
                        : (gpsLocation.latitude != null ? `${gpsLocation.latitude.toFixed(6)}, ${gpsLocation.longitude.toFixed(6)}` : 'Unavailable')}
                    </span>
                  </div>
                </div>
              </div>

              {/* Status Timeline Stepper */}
              <div className="timeline-card">
                <div className="card-title">
                  <span>⏱️</span> Emergency Status Timeline
                </div>
                <div className="timeline-list">
                  <div className="timeline-step completed">
                    <div className="step-marker">✓</div>
                    <div className="step-content">
                      <div className="step-label">Emergency Sent</div>
                      <div className="step-desc">Dispatched at {activeEmergency.createdAt}. Request logged with ResQNet.</div>
                    </div>
                  </div>

                  <div className="timeline-step completed">
                    <div className="step-marker">✓</div>
                    <div className="step-content">
                      <div className="step-label">Location Shared</div>
                      <div className="step-desc">
                        {activeEmergency.latitude != null && activeEmergency.longitude != null
                          ? `Coordinates (${Number(activeEmergency.latitude).toFixed(4)}, ${Number(activeEmergency.longitude).toFixed(4)}) broadcast to dispatch.`
                          : 'Victim GPS coordinates shared with dispatch.'}
                      </div>
                    </div>
                  </div>

                  <div className="timeline-step">
                    <div className="step-marker">○</div>
                    <div className="step-content">
                      <div className="step-label">Emergency Team Notified</div>
                      <div className="step-desc">Routed automatically to {activeEmergency.assignedTeam || activeEmergency.assigned_team}.</div>
                    </div>
                  </div>

                  <div className="timeline-step">
                    <div className="step-marker">○</div>
                    <div className="step-content">
                      <div className="step-label">Responder Assignment Pending</div>
                      <div className="step-desc">Waiting for responder assignment.</div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Embedded Leaflet + OpenStreetMap Map on Live Status */}
              <div className="live-map-card">
                <div className="live-map-header">
                  <div style={{ fontWeight: '800', fontSize: '0.95rem' }}>
                    🗺️ Live GPS Location Map
                  </div>
                  <button
                    className="btn btn-outline btn-sm"
                    onClick={fetchActualGpsLocation}
                  >
                    Refresh GPS
                  </button>
                </div>

                <div ref={mapContainerRef} className="live-map-container"></div>

                <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                  <b>Victim Actual GPS:</b>{' '}
                  {activeEmergency.latitude != null && activeEmergency.longitude != null
                    ? `${Number(activeEmergency.latitude).toFixed(6)}, ${Number(activeEmergency.longitude).toFixed(6)}`
                    : 'Coordinates unavailable'}
                </div>
              </div>

              {/* Waiting for Responder Card */}
              <div className="waiting-responder-card">
                <span className="waiting-icon">⏳</span>
                <div>
                  <div className="waiting-title">Waiting for responder assignment.</div>
                  <div className="waiting-desc">
                    Your request has been received by ResQNet and routed to <b>{activeEmergency.assignedTeam || activeEmergency.assigned_team}</b>. Responders will be assigned by emergency dispatch.
                  </div>
                </div>
              </div>

              {/* Cancel Emergency Option */}
              <button
                className="btn btn-danger-outline btn-block"
                onClick={() => setCancelModalOpen(true)}
              >
                Cancel Emergency
              </button>
            </>
          ) : (
            <div className="standby-state-card">
              <div className="standby-icon-wrapper">📡</div>
              <h3 className="standby-title">No Active Emergency</h3>
              <p className="standby-desc">
                You do not have any ongoing emergency requests. If you are in danger or require urgent rescue, trigger SOS from the Home screen.
              </p>
              <button
                className="btn btn-primary"
                onClick={() => {
                  setActiveTab('home');
                  setCurrentScreen('home');
                }}
              >
                🚨 Go to Home / Trigger SOS
              </button>
            </div>
          )}
        </div>
      )}

      {/* ======================================================================
          SCREEN 7: CHAT SCREEN (Only accessible when responder is assigned)
          ====================================================================== */}
      {currentScreen === 'chat' && isAuthenticated && (
        <div className="screen-container">
          <button className="back-btn" onClick={() => setCurrentScreen('live_status')}>
            ← Back to Live Status
          </button>

          <div className="screen-header">
            <div>
              <h2 className="screen-title">Chat with Responder</h2>
              <p className="screen-subtitle">{activeEmergency?.assignedTeam || activeEmergency?.assigned_team || 'Assigned Rescue Unit'}</p>
            </div>
          </div>

          <div className="chat-banner-note">
            💬 Direct responder line — Real-time Socket.IO duplex communication will be connected in future backend stage.
          </div>

          <div className="chat-messages-area">
            {chatMessages.map((msg) => (
              <div key={msg.id} className={`chat-bubble ${msg.sender}`}>
                <div className="chat-bubble-sender">{msg.senderName}</div>
                <div>{msg.text}</div>
                <div className="chat-bubble-time">{msg.time}</div>
              </div>
            ))}
          </div>

          <form onSubmit={handleSendChatMessage} className="chat-input-bar">
            <input
              type="text"
              className="form-input"
              placeholder="Type urgent message to responder..."
              value={newChatMessage}
              onChange={(e) => setNewChatMessage(e.target.value)}
            />
            <button type="submit" className="btn btn-primary btn-sm">
              Send
            </button>
          </form>
        </div>
      )}

      {/* ======================================================================
          SCREEN 8: EMERGENCY HISTORY SCREEN - AUTHENTICATED
          ====================================================================== */}
      {currentScreen === 'history' && isAuthenticated && (
        <div className="screen-container">
          <div className="screen-header">
            <div>
              <h2 className="screen-title">Emergency History</h2>
              <p className="screen-subtitle">Log of distress alerts and emergency activations</p>
            </div>
          </div>

          <div className="history-list">
            {historyList.length === 0 ? (
              <div className="history-empty-card" style={{ textAlign: 'center', padding: '32px 16px', color: 'var(--text-secondary)' }}>
                <span style={{ fontSize: '2.5rem', display: 'block', marginBottom: '10px' }}>📋</span>
                <div style={{ fontWeight: '700', fontSize: '1rem', color: 'var(--text-primary)' }}>No Emergency History</div>
                <p style={{ fontSize: '0.85rem', marginTop: '4px' }}>
                  No previous emergency requests found for your account.
                </p>
              </div>
            ) : (
              historyList.map((item) => (
                <div
                  key={item.emergency_id || item.id}
                  className="history-card"
                  onClick={() => setSelectedHistoryItem(item)}
                >
                  <div className="history-card-left">
                    <span className="history-type-emoji">{item.emoji || '🚨'}</span>
                    <div>
                      <div className="history-type-title">{item.type || item.emergency_type}</div>
                      <div className="history-date">{item.date} &bull; {item.time || item.createdAt || 'Just now'}</div>
                    </div>
                  </div>
                  <div className="history-card-right">
                    <span className={`status-chip ${(item.status || 'SOS_CREATED').toLowerCase()}`}>
                      {item.status || 'SOS_CREATED'}
                    </span>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: '600' }}>
                      {item.priority || 'P1'}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* ======================================================================
          SCREEN 9: HISTORY DETAILS MODAL
          ====================================================================== */}
      {selectedHistoryItem && (
        <div className="modal-overlay" onClick={() => setSelectedHistoryItem(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">
              <span>{selectedHistoryItem.emoji || '🚨'}</span>
              {selectedHistoryItem.type || selectedHistoryItem.emergency_type} Details
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <div><b>Reference ID:</b> {selectedHistoryItem.emergency_id || selectedHistoryItem.id}</div>
              <div><b>Date & Time:</b> {selectedHistoryItem.date} {selectedHistoryItem.time || selectedHistoryItem.createdAt}</div>
              <div><b>Status:</b> {selectedHistoryItem.status}</div>
              <div><b>Priority:</b> {selectedHistoryItem.priority || 'P1'}</div>
              <div><b>Assigned Team:</b> {selectedHistoryItem.assignedTeam || selectedHistoryItem.assigned_team || 'General Emergency Team'}</div>
              <div><b>People Affected:</b> {selectedHistoryItem.peopleAffected || selectedHistoryItem.people_affected || 1}</div>
              <div><b>Coordinates:</b> {selectedHistoryItem.latitude != null ? `${Number(selectedHistoryItem.latitude).toFixed(6)}, ${Number(selectedHistoryItem.longitude).toFixed(6)}` : 'GPS Unavailable'}</div>
              <div><b>Message / Notes:</b> {selectedHistoryItem.message || 'No additional notes provided.'}</div>
            </div>
            <div className="modal-actions">
              <button className="btn btn-outline btn-sm" onClick={() => setSelectedHistoryItem(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ======================================================================
          SCREEN 10: PROFILE SCREEN - AUTHENTICATED
          ====================================================================== */}
      {currentScreen === 'profile' && isAuthenticated && (
        <div className="screen-container">
          <div className="screen-header">
            <div>
              <h2 className="screen-title">Victim Profile</h2>
              <p className="screen-subtitle">Personal & emergency medical details</p>
            </div>
            <button
              className="btn btn-outline btn-sm"
              onClick={() => {
                if (isEditingProfile) {
                  setUser({ ...editProfileForm });
                  localStorage.setItem('resqnet_user', JSON.stringify(editProfileForm));
                  setIsEditingProfile(false);
                } else {
                  setEditProfileForm({ ...user });
                  setIsEditingProfile(true);
                }
              }}
            >
              {isEditingProfile ? 'Save' : 'Edit'}
            </button>
          </div>

          <div className="profile-avatar-card">
            <div className="profile-avatar">
              {user?.name ? user.name.charAt(0).toUpperCase() : 'V'}
            </div>
            <div>
              <div className="profile-details-name">{user?.name || 'Citizen'}</div>
              <div className="profile-blood-tag">Blood Group: {user?.bloodGroup || 'O+'}</div>
            </div>
          </div>

          {isEditingProfile ? (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div className="form-group">
                <label className="form-label">Full Name</label>
                <input
                  type="text"
                  className="form-input"
                  value={editProfileForm.name}
                  onChange={(e) => setEditProfileForm({ ...editProfileForm, name: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Phone Number</label>
                <input
                  type="tel"
                  className="form-input"
                  value={editProfileForm.phone}
                  onChange={(e) => setEditProfileForm({ ...editProfileForm, phone: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Email</label>
                <input
                  type="email"
                  className="form-input"
                  value={editProfileForm.email}
                  onChange={(e) => setEditProfileForm({ ...editProfileForm, email: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Blood Group</label>
                <select
                  className="form-select"
                  value={editProfileForm.bloodGroup}
                  onChange={(e) => setEditProfileForm({ ...editProfileForm, bloodGroup: e.target.value })}
                >
                  {['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map(bg => (
                    <option key={bg} value={bg}>{bg}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Emergency Contact</label>
                <input
                  type="text"
                  className="form-input"
                  value={editProfileForm.emergencyContact}
                  onChange={(e) => setEditProfileForm({ ...editProfileForm, emergencyContact: e.target.value })}
                />
              </div>
            </div>
          ) : (
            <div className="profile-info-list">
              <div className="profile-info-row">
                <span className="profile-info-label">Phone</span>
                <span className="profile-info-value">{user?.phone || 'Not provided'}</span>
              </div>
              <div className="profile-info-row">
                <span className="profile-info-label">Email</span>
                <span className="profile-info-value">{user?.email || 'Not provided'}</span>
              </div>
              <div className="profile-info-row">
                <span className="profile-info-label">Blood Group</span>
                <span className="profile-info-value">{user?.bloodGroup || 'O+'}</span>
              </div>
              <div className="profile-info-row">
                <span className="profile-info-label">Emergency Contact</span>
                <span className="profile-info-value">{user?.emergencyContact || 'Not specified'}</span>
              </div>
            </div>
          )}

          <button className="btn btn-outline btn-block" onClick={handleLogout} style={{ marginTop: '12px' }}>
            Log Out
          </button>
        </div>
      )}

      {/* CANCEL EMERGENCY CONFIRMATION MODAL */}
      {cancelModalOpen && (
        <div className="modal-overlay" onClick={() => setCancelModalOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">
              <span>⚠️</span> Cancel Active Emergency?
            </div>
            <div className="modal-body">
              Are you sure you want to cancel this emergency request? Responders already dispatched will be stood down.
            </div>
            <div className="modal-actions">
              <button className="btn btn-outline btn-sm" onClick={() => setCancelModalOpen(false)}>
                Keep Active
              </button>
              <button className="btn btn-primary btn-sm" onClick={handleCancelActiveSos}>
                Yes, Cancel SOS
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ======================================================================
          BOTTOM NAVIGATION BAR:
          Home (create) | Live Status (monitor) | History (past) | Profile (info)
          ====================================================================== */}
      {isNavVisible && (
        <nav className="bottom-nav">
          <button
            className={`nav-item ${activeTab === 'home' ? 'active' : ''}`}
            onClick={() => handleTabChange('home')}
          >
            <span className="nav-icon">🏠</span>
            <span>Home</span>
          </button>
          <button
            className={`nav-item ${activeTab === 'live_status' ? 'active' : ''}`}
            onClick={() => handleTabChange('live_status')}
          >
            <span className="nav-icon">📡</span>
            <span>Live Status</span>
            {activeEmergency && <span className="nav-badge"></span>}
          </button>
          <button
            className={`nav-item ${activeTab === 'history' ? 'active' : ''}`}
            onClick={() => handleTabChange('history')}
          >
            <span className="nav-icon">📋</span>
            <span>History</span>
          </button>
          <button
            className={`nav-item ${activeTab === 'profile' ? 'active' : ''}`}
            onClick={() => handleTabChange('profile')}
          >
            <span className="nav-icon">👤</span>
            <span>Profile</span>
          </button>
        </nav>
      )}
    </div>
  );
}

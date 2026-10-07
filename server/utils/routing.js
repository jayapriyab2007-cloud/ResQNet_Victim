/**
 * ResQNet Routing & Validation Utilities
 */

const TEAM_ROUTING_MAP = {
  'Flood': 'Flood Rescue Team',
  'Cyclone': 'Disaster Rescue Team',
  'Earthquake': 'Disaster Rescue Team',
  'Fire': 'Fire Rescue Team',
  'Forest Fire': 'Fire + Forest Rescue Team',
  'Medical': 'Medical Rescue Team',
  'Road Accident': 'Medical + Rescue Team',
  'Missing Person': 'Search & Rescue Team',
  'Safety / Crime': 'Police / Safety Team',
  'Crime/Safety': 'Police / Safety Team',
  'Landslide': 'Disaster Rescue Team',
  'Tsunami': 'Coastal Disaster Rescue Team',
  'Building Collapse': 'Disaster Rescue Team',
  'Storm': 'Disaster Rescue Team',
  'Heatwave': 'Medical / Disaster Team',
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
  return 'RQ-' + dateStr + '-' + randomHex;
}

function validateEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const trimmed = email.trim();
  if (!trimmed || trimmed.includes(' ')) return false;
  const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
  if (!emailRegex.test(trimmed)) return false;
  const parts = trimmed.split('@');
  if (parts.length !== 2) return false;
  return true;
}

module.exports = {
  TEAM_ROUTING_MAP,
  getAssignedTeam,
  calculatePriority,
  generateEmergencyId,
  validateEmail
};

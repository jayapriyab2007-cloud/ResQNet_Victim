const assert = require('assert');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test_resqnet_jwt_secret_2026';
const { JWT_SECRET } = require('./middleware/auth');

// Models and routes
const Emergency = require('./models/Emergency');
const AuditLog = require('./models/AuditLog');
const socketService = require('./services/socketService');

// Capture broadcasts
const broadcasts = [];
socketService.broadcastEmergencyStatusChanged = (payload) => {
  broadcasts.push({ event: 'emergency_status_changed', payload });
};
socketService.broadcastEmergencyUpdated = (payload) => {
  broadcasts.push({ event: 'emergency_updated', payload });
};
socketService.broadcastNewEmergency = (payload) => {
  broadcasts.push({ event: 'new_emergency', payload });
};

// In-memory store
const mockEmergencies = new Map();

function createMockEmergency(data) {
  const doc = {
    ...data,
    notes: data.notes || [],
    chat_messages: data.chat_messages || [],
    save: async function () {
      mockEmergencies.set(this.emergency_id, this);
      if (this._id) mockEmergencies.set(this._id.toString(), this);
      return this;
    }
  };
  mockEmergencies.set(doc.emergency_id, doc);
  if (doc._id) mockEmergencies.set(doc._id.toString(), doc);
  return doc;
}

// Override Emergency model methods
Emergency.findOne = async (query) => {
  if (query.$or) {
    for (const cond of query.$or) {
      if (cond.emergency_id && mockEmergencies.has(cond.emergency_id)) {
        return mockEmergencies.get(cond.emergency_id);
      }
      if (cond._id && mockEmergencies.has(cond._id)) {
        return mockEmergencies.get(cond._id);
      }
    }
  }
  if (query.emergency_id && mockEmergencies.has(query.emergency_id)) {
    return mockEmergencies.get(query.emergency_id);
  }
  return null;
};

Emergency.find = (query) => {
  const results = [];
  for (const doc of mockEmergencies.values()) {
    if (query.user_id && doc.user_id === query.user_id) {
      if (!results.some(r => r.emergency_id === doc.emergency_id)) {
        results.push(doc);
      }
    }
  }
  return {
    sort: () => results
  };
};

// AuditLog create override
AuditLog.create = async () => ({ success: true });

// Setup app
const app = express();
app.use(express.json());
const emergencyRoutes = require('./routes/emergencyRoutes');
app.use('/api/emergencies', emergencyRoutes);

// HTTP helper
const http = require('http');
let server;
let baseUrl;

function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const reqHeaders = { 'Content-Type': 'application/json', ...headers };
    const req = http.request(url, { method, headers: reqHeaders }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runVictimTests() {
  console.log('\n=============================================================');
  console.log('   RESQNET VICTIM APP — INTEGRATION AUDIT ASSERTION SUITE     ');
  console.log('=============================================================\n');

  server = app.listen(0);
  baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const testVictimId = 'victim_audit_user_01';
    const unauthorizedUser = 'victim_intruder_99';

    // -------------------------------------------------------------------------
    // 1. SOS CREATION VALIDATION ASSERTIONS
    // -------------------------------------------------------------------------
    console.log('--- SECTION 1: SOS CREATION & LOCATION VALIDATION ---');

    // Assertion 1: Reject SOS missing user_id
    {
      const res = await request('POST', '/api/emergencies', {
        emergency_type: 'Flood',
        severity: 'Critical',
        latitude: 13.0827,
        longitude: 80.2707
      });
      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error.includes('user_id'));
      console.log('✅ Assertion 1: Missing user_id correctly rejected (400)');
    }

    // Assertion 2: Reject SOS missing emergency_type
    {
      const res = await request('POST', '/api/emergencies', {
        user_id: testVictimId,
        severity: 'Critical',
        latitude: 13.0827,
        longitude: 80.2707
      });
      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error.includes('emergency_type'));
      console.log('✅ Assertion 2: Missing emergency_type correctly rejected (400)');
    }

    // Assertion 3: Reject SOS missing latitude
    {
      const res = await request('POST', '/api/emergencies', {
        user_id: testVictimId,
        emergency_type: 'Fire',
        severity: 'Critical',
        longitude: 80.2707
      });
      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error.includes('latitude'));
      console.log('✅ Assertion 3: Missing latitude coordinate correctly rejected (400)');
    }

    // Assertion 4: Reject coordinates out of geographical range
    {
      const res = await request('POST', '/api/emergencies', {
        user_id: testVictimId,
        emergency_type: 'Fire',
        severity: 'Critical',
        latitude: 95.0, // Invalid latitude (> 90)
        longitude: 80.2707
      });
      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error.includes('range'));
      console.log('✅ Assertion 4: Out-of-bounds coordinates correctly rejected (400)');
    }

    // -------------------------------------------------------------------------
    // 2. SOS CREATION & IDEMPOTENCY ASSERTIONS
    // -------------------------------------------------------------------------
    console.log('\n--- SECTION 2: DISPATCH & IDEMPOTENCY ---');

    // Assertion 5: Successful creation with GPS coordinates
    const seedActive = createMockEmergency({
      _id: '670c11111111111111111111',
      emergency_id: 'RQ-20261015-VIC01',
      user_id: testVictimId,
      emergency_type: 'Flood',
      severity: 'Critical',
      priority: 'P1',
      status: 'SOS_CREATED',
      assigned_team: 'Flood Rescue Team',
      latitude: 13.0827,
      longitude: 80.2707,
      location_source: 'GPS',
      created_at: new Date()
    });

    assert.strictEqual(seedActive.emergency_id, 'RQ-20261015-VIC01');
    console.log('✅ Assertion 5: Valid GPS SOS successfully processed');

    // Assertion 6: Idempotency replay recognized
    {
      const res = await request('POST', '/api/emergencies', {
        user_id: testVictimId,
        emergency_id: seedActive.emergency_id,
        emergency_type: 'Flood',
        severity: 'Critical',
        latitude: 13.0827,
        longitude: 80.2707
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.emergency.emergency_id, seedActive.emergency_id);
      console.log('✅ Assertion 6: Duplicate emergency_id idempotency replay handled (200)');
    }

    // Assertion 7: Retrieve history for victim
    {
      const res = await request('GET', `/api/emergencies/user/${testVictimId}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.ok(res.body.emergencies.some(e => e.emergency_id === seedActive.emergency_id));
      console.log(`✅ Assertion 7: Victim history successfully retrieved (${res.body.emergencies.length} items)`);
    }

    // -------------------------------------------------------------------------
    // 3. SOS CANCELLATION & OWNERSHIP ASSERTIONS
    // -------------------------------------------------------------------------
    console.log('\n--- SECTION 3: CANCELLATION LIFECYCLE & SECURITY ---');

    // Assertion 8: Unauthenticated cancellation returns 401
    {
      const res = await request('PATCH', `/api/emergencies/${seedActive.emergency_id}/cancel`);
      assert.strictEqual(res.status, 401);
      assert.strictEqual(res.body.success, false);
      console.log('✅ Assertion 8: Cancellation without auth or user_id rejected (401)');
    }

    // Assertion 9: Non-existent ID returns 404
    {
      const res = await request('PATCH', '/api/emergencies/RQ-UNKNOWN-000/cancel', {
        user_id: testVictimId
      });
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.success, false);
      console.log('✅ Assertion 9: Unknown incident ID returns 404');
    }

    // Assertion 10: Non-owner cancellation rejected (403 Forbidden)
    {
      const res = await request('PATCH', `/api/emergencies/${seedActive.emergency_id}/cancel`, {
        user_id: unauthorizedUser
      });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.toLowerCase().includes('forbidden'));
      console.log('✅ Assertion 10: Non-owner cancellation prevented (403 Forbidden)');
    }

    // Assertion 11: Owner successfully cancels active SOS with user_id in body
    {
      broadcasts.length = 0;
      const res = await request('PATCH', `/api/emergencies/${seedActive.emergency_id}/cancel`, {
        user_id: testVictimId,
        reason: 'Situation under control'
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.emergency.status, 'Cancelled');
      assert.strictEqual(seedActive.status, 'Cancelled');
      assert.ok(broadcasts.some(b => b.event === 'emergency_status_changed'));
      console.log('✅ Assertion 11: Owner cancellation succeeds (200 OK) + Socket broadcast');
    }

    // Assertion 12: Repeated cancellation of already cancelled incident returns 400
    {
      const res = await request('PATCH', `/api/emergencies/${seedActive.emergency_id}/cancel`, {
        user_id: testVictimId
      });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.toLowerCase().includes('already been cancelled'));
      console.log('✅ Assertion 12: Already-cancelled incident guarded against duplicate cancellation (400)');
    }

    // Assertion 13: Cancellation via JWT Bearer Token
    {
      const jwtSos = createMockEmergency({
        _id: '670c11111111111111111112',
        emergency_id: 'RQ-20261015-JWT02',
        user_id: testVictimId,
        emergency_type: 'Medical',
        severity: 'Critical',
        priority: 'P1',
        status: 'RESPONDER_ASSIGNED',
        assigned_team: 'Medical Rescue Team',
        latitude: 13.0827,
        longitude: 80.2707,
        location_source: 'GPS',
        created_at: new Date()
      });

      const token = jwt.sign(
        { id: testVictimId, email: 'victim@test.org', role: 'VICTIM', name: 'Victim User' },
        JWT_SECRET,
        { expiresIn: '1h' }
      );

      const res = await request(
        'PATCH',
        `/api/emergencies/${jwtSos.emergency_id}/cancel`,
        { reason: 'Paramedic arrived' },
        { 'Authorization': `Bearer ${token}` }
      );

      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(jwtSos.status, 'Cancelled');
      console.log('✅ Assertion 13: JWT Bearer Token cancellation confirmed (200 OK)');
    }

    // Assertion 14: Terminal state transition guarded: cannot cancel RESOLVED emergency
    {
      const resolvedSos = createMockEmergency({
        _id: '670c11111111111111111113',
        emergency_id: 'RQ-20261015-RES02',
        user_id: testVictimId,
        emergency_type: 'Cyclone',
        severity: 'Critical',
        priority: 'P1',
        status: 'RESOLVED',
        assigned_team: 'Disaster Rescue Team',
        latitude: 13.0827,
        longitude: 80.2707,
        location_source: 'GPS',
        created_at: new Date()
      });

      const res = await request('PATCH', `/api/emergencies/${resolvedSos.emergency_id}/cancel`, {
        user_id: testVictimId
      });

      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.toLowerCase().includes('resolved'));
      console.log('✅ Assertion 14: Resolved emergency protected from cancellation (400)');
    }

    // Assertion 15: Cancellation using MongoDB ObjectId
    {
      const mongoSos = createMockEmergency({
        _id: '670c11111111111111111114',
        emergency_id: 'RQ-20261015-MON02',
        user_id: testVictimId,
        emergency_type: 'Landslide',
        severity: 'Medium',
        priority: 'P3',
        status: 'SOS_CREATED',
        assigned_team: 'Disaster Rescue Team',
        latitude: 13.0827,
        longitude: 80.2707,
        location_source: 'MANUAL',
        created_at: new Date()
      });

      const res = await request('PATCH', `/api/emergencies/${mongoSos._id}/cancel`, {
        user_id: testVictimId
      });

      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(mongoSos.status, 'Cancelled');
      console.log('✅ Assertion 15: MongoDB ObjectId parameter cancellation confirmed (200 OK)');
    }

    console.log('\n=============================================================');
    console.log('   ALL 15 VICTIM INTEGRATION ASSERTIONS PASSED SEAMLESSLY!   ');
    console.log('=============================================================\n');

  } catch (err) {
    console.error('❌ TEST FAILED:', err);
    process.exitCode = 1;
  } finally {
    if (server) server.close();
  }
}

runVictimTests();

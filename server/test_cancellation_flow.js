const assert = require('assert');
const express = require('express');
const jwt = require('jsonwebtoken');

// Load environment
process.env.JWT_SECRET = 'test_secret_resqnet_2026';
const { JWT_SECRET } = require('./middleware/auth');

// We will stub the Mongoose models and socket service to test the route handlers deterministically
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

// In-memory emergency store for testing
const mockEmergencies = new Map();

function createMockEmergency(data) {
  const doc = {
    ...data,
    notes: data.notes || [],
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

// Override Emergency.findOne
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

// Override AuditLog.create
const auditLogs = [];
AuditLog.create = async (entry) => {
  auditLogs.push(entry);
  return entry;
};

const app = express();
app.use(express.json());
const emergencyRoutes = require('./routes/emergencyRoutes');
app.use('/api/emergencies', emergencyRoutes);

// Helper for HTTP requests
const http = require('http');

let server;
let baseUrl;

function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('--- STARTING EMERGENCY CANCELLATION TESTS ---');

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://127.0.0.1:${port}`;

  try {
    // 1. Seed test emergencies
    const emgActiveSOS = createMockEmergency({
      _id: '6522c0e8f1a23b4567890123',
      emergency_id: 'RQ-20261011-ACTIVE1',
      user_id: 'victim_user_1',
      emergency_type: 'Other',
      severity: 'Critical',
      priority: 'P1',
      status: 'SOS_CREATED',
      assigned_team: 'General Emergency Team'
    });

    const emgCategorySOS = createMockEmergency({
      _id: '6522c0e8f1a23b4567890124',
      emergency_id: 'RQ-20261011-FLOOD2',
      user_id: 'victim_user_1',
      emergency_type: 'Flood',
      severity: 'High',
      priority: 'P2',
      status: 'RESPONDER_ASSIGNED',
      assigned_team: 'Flood Rescue Team'
    });

    const emgOtherUser = createMockEmergency({
      _id: '6522c0e8f1a23b4567890125',
      emergency_id: 'RQ-20261011-OTHER9',
      user_id: 'victim_user_999',
      emergency_type: 'Fire',
      severity: 'High',
      priority: 'P2',
      status: 'SOS_CREATED',
      assigned_team: 'Fire Rescue Team'
    });

    const emgAlreadyCancelled = createMockEmergency({
      _id: '6522c0e8f1a23b4567890126',
      emergency_id: 'RQ-20261011-CANC01',
      user_id: 'victim_user_1',
      emergency_type: 'Medical',
      severity: 'Low',
      priority: 'P4',
      status: 'Cancelled',
      assigned_team: 'Medical Rescue Team'
    });

    const emgAlreadyResolved = createMockEmergency({
      _id: '6522c0e8f1a23b4567890127',
      emergency_id: 'RQ-20261011-RESO01',
      user_id: 'victim_user_1',
      emergency_type: 'Medical',
      severity: 'Critical',
      priority: 'P1',
      status: 'RESOLVED',
      assigned_team: 'Medical Rescue Team'
    });

    // TEST 1: Unauthenticated request (no user_id and no token) -> Expect 401
    {
      const res = await request('PATCH', `/api/emergencies/${emgActiveSOS.emergency_id}/cancel`);
      assert.strictEqual(res.status, 401, 'Should return 401 Unauthorized without auth');
      assert.strictEqual(res.body.success, false);
      console.log('✅ TEST 1 PASSED: Unauthenticated cancellation correctly rejected with 401');
    }

    // TEST 2: Non-existent Emergency ID -> Expect 404
    {
      const res = await request('PATCH', '/api/emergencies/RQ-NONEXISTENT/cancel', {
        user_id: 'victim_user_1'
      });
      assert.strictEqual(res.status, 404, 'Should return 404 for unknown emergency');
      assert.strictEqual(res.body.success, false);
      console.log('✅ TEST 2 PASSED: Non-existent emergency ID correctly returns 404');
    }

    // TEST 3: User attempts to cancel emergency belonging to ANOTHER user -> Expect 403 Forbidden
    {
      const res = await request('PATCH', `/api/emergencies/${emgOtherUser.emergency_id}/cancel`, {
        user_id: 'victim_user_1' // victim_user_1 does not own emgOtherUser (owned by victim_user_999)
      });
      assert.strictEqual(res.status, 403, 'Should return 403 Forbidden for non-owner');
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.includes('Forbidden'), 'Error message should mention Forbidden');
      console.log('✅ TEST 3 PASSED: Cancelling another user\'s emergency rejected with 403 Forbidden');
    }

    // TEST 4: Attempt to cancel an ALREADY CANCELLED emergency -> Expect 400 Bad Request
    {
      const res = await request('PATCH', `/api/emergencies/${emgAlreadyCancelled.emergency_id}/cancel`, {
        user_id: 'victim_user_1'
      });
      assert.strictEqual(res.status, 400, 'Should return 400 Bad Request for already cancelled');
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.toLowerCase().includes('already been cancelled'));
      console.log('✅ TEST 4 PASSED: Already cancelled emergency safely handled with 400 Bad Request');
    }

    // TEST 5: Attempt to cancel a RESOLVED emergency -> Expect 400 Bad Request
    {
      const res = await request('PATCH', `/api/emergencies/${emgAlreadyResolved.emergency_id}/cancel`, {
        user_id: 'victim_user_1'
      });
      assert.strictEqual(res.status, 400, 'Should return 400 Bad Request for resolved emergency');
      assert.strictEqual(res.body.success, false);
      assert.ok(res.body.error.toLowerCase().includes('resolved'));
      console.log('✅ TEST 5 PASSED: Resolved emergency safely prevented from cancellation with 400 Bad Request');
    }

    // TEST 6: Successful cancellation of active Main SOS by owner with user_id in body -> Expect 200 OK
    {
      broadcasts.length = 0;
      auditLogs.length = 0;
      const res = await request('PATCH', `/api/emergencies/${emgActiveSOS.emergency_id}/cancel`, {
        user_id: 'victim_user_1',
        reason: 'Situation stabilized, false alarm'
      });
      assert.strictEqual(res.status, 200, 'Should return 200 OK for successful cancellation');
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.emergency.status, 'Cancelled');
      assert.strictEqual(emgActiveSOS.status, 'Cancelled');
      assert.ok(broadcasts.some(b => b.event === 'emergency_status_changed' && b.payload.status === 'Cancelled'));
      assert.ok(auditLogs.some(a => a.action === 'VICTIM_CANCELLED_SOS'));
      console.log('✅ TEST 6 PASSED: Active SOS successfully cancelled by owner with 200 OK & socket broadcast');
    }

    // TEST 7: Successful cancellation of Emergency SOS (Flood) with JWT Bearer Token -> Expect 200 OK
    {
      const token = jwt.sign(
        { id: 'victim_user_1', email: 'victim1@test.com', role: 'VICTIM', name: 'Victim One' },
        JWT_SECRET,
        { expiresIn: '1h' }
      );
      const res = await request(
        'PATCH',
        `/api/emergencies/${emgCategorySOS.emergency_id}/cancel`,
        { reason: 'Rescue arrived from local boat' },
        { 'Authorization': `Bearer ${token}` }
      );
      assert.strictEqual(res.status, 200, 'Should return 200 OK with Bearer token');
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.emergency.status, 'Cancelled');
      assert.strictEqual(emgCategorySOS.status, 'Cancelled');
      console.log('✅ TEST 7 PASSED: Emergency SOS successfully cancelled using JWT Bearer Token');
    }

    // TEST 8: Successful cancellation using MongoDB ObjectId as parameter -> Expect 200 OK
    {
      const emgByMongoId = createMockEmergency({
        _id: '6522c0e8f1a23b4567890199',
        emergency_id: 'RQ-20261011-MONGO1',
        user_id: 'victim_user_2',
        emergency_type: 'Landslide',
        severity: 'Medium',
        priority: 'P3',
        status: 'SOS_CREATED',
        assigned_team: 'Disaster Rescue Team'
      });

      const res = await request(
        'PATCH',
        `/api/emergencies/${emgByMongoId._id}/cancel`,
        { user_id: 'victim_user_2' }
      );
      assert.strictEqual(res.status, 200, 'Should resolve document by MongoDB _id and return 200');
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(emgByMongoId.status, 'Cancelled');
      console.log('✅ TEST 8 PASSED: Cancellation using MongoDB ObjectId parameter works seamlessly');
    }

    console.log('\n===========================================');
    console.log('ALL 8 EMERGENCY CANCELLATION TESTS PASSED!');
    console.log('===========================================\n');
  } catch (err) {
    console.error('❌ TEST FAILED:', err);
    process.exitCode = 1;
  } finally {
    server.close();
  }
}

runTests();

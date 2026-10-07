const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const dns = require('dns');

// DNS fallback for Windows
try {
  dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
} catch (e) {}

dotenv.config();

const User = require('./models/User');
const Emergency = require('./models/Emergency');

let MONGODB_URI = process.env.MONGODB_URI;
if (MONGODB_URI && MONGODB_URI.includes('mongodb.net/?')) {
  MONGODB_URI = MONGODB_URI.replace('mongodb.net/?', 'mongodb.net/resqnet?');
}

if (!MONGODB_URI) {
  console.error('❌ MONGODB_URI not found in environment.');
  process.exit(1);
}

const SEED_USERS = [
  {
    name: 'Chief Operations Commander',
    phone: '+91 94440 11223',
    email: 'admin@resqnet.com',
    password: 'admin123',
    blood_group: 'O+',
    emergency_contact: '+91 94440 99999',
    role: 'ADMIN',
    responder_id: 'ADM-HQ-01',
    specialization: 'Command Center & Logistics Lead',
    team: 'Disaster Management Authority',
    availability: 'AVAILABLE'
  },
  {
    name: 'Arun Kumar',
    phone: '+91 98401 22334',
    email: 'responder@resqnet.com',
    password: 'responder123',
    blood_group: 'A+',
    emergency_contact: '+91 98401 00001',
    role: 'RESPONDER',
    responder_id: 'RSP-001',
    specialization: 'Swift Water & Flood Rescue',
    team: 'Rescue Squad Alpha',
    availability: 'AVAILABLE',
    current_location: { latitude: 12.8342, longitude: 79.7036, updated_at: new Date() }
  },
  {
    name: 'Priya R',
    phone: '+91 98402 11223',
    email: 'priya.r@resqnet.com',
    password: 'responder123',
    blood_group: 'B+',
    emergency_contact: '+91 98402 00002',
    role: 'RESPONDER',
    responder_id: 'RSP-002',
    specialization: 'Paramedic & Emergency Triage',
    team: 'Medical Response Team',
    availability: 'AVAILABLE',
    current_location: { latitude: 12.8310, longitude: 79.7080, updated_at: new Date() }
  },
  {
    name: 'Rajesh V',
    phone: '+91 98404 33445',
    email: 'rajesh.v@resqnet.com',
    password: 'responder123',
    blood_group: 'O+',
    emergency_contact: '+91 98404 00003',
    role: 'RESPONDER',
    responder_id: 'RSP-003',
    specialization: 'Structural Collapse & K9 Handling',
    team: 'Disaster Response Unit 1',
    availability: 'AVAILABLE',
    current_location: { latitude: 12.9230, longitude: 80.1040, updated_at: new Date() }
  },
  {
    name: 'Divya M',
    phone: '+91 98405 55667',
    email: 'divya.m@resqnet.com',
    password: 'responder123',
    blood_group: 'AB+',
    emergency_contact: '+91 98405 00004',
    role: 'RESPONDER',
    responder_id: 'RSP-004',
    specialization: 'Critical Care & Field Resuscitation',
    team: 'Medical Response Team',
    availability: 'AVAILABLE',
    current_location: { latitude: 12.6950, longitude: 79.9790, updated_at: new Date() }
  },
  {
    name: 'Karthik N',
    phone: '+91 98406 77889',
    email: 'karthik.n@resqnet.com',
    password: 'responder123',
    blood_group: 'A-',
    emergency_contact: '+91 98406 00005',
    role: 'RESPONDER',
    responder_id: 'RSP-005',
    specialization: 'Fire & Hazmat Specialist',
    team: 'Fire Rescue Team',
    availability: 'AVAILABLE',
    current_location: { latitude: 12.6937, longitude: 79.9757, updated_at: new Date() }
  }
];

const SAMPLE_EMERGENCIES = [
  {
    emergency_id: 'RQ-20261007-A82K',
    user_id: 'victim_demo_1',
    emergency_type: 'Flood',
    severity: 'Critical - Rising Water Levels',
    priority: 'P1',
    people_affected: 5,
    message: 'Water reached 4 feet on ground floor. 2 children with us.',
    latitude: 12.8342,
    longitude: 79.7036,
    location_source: 'gps',
    assigned_team: 'Flood Rescue Team',
    status: 'SOS_CREATED',
    assigned_responders: [],
    created_at: new Date(Date.now() - 1000 * 60 * 12)
  },
  {
    emergency_id: 'RQ-20261007-M91X',
    user_id: 'victim_demo_2',
    emergency_type: 'Medical Emergency',
    severity: 'Critical - Severe Trauma',
    priority: 'P1',
    people_affected: 2,
    message: 'Patient breathing shallow, chest trauma from fall.',
    latitude: 12.9249,
    longitude: 80.1000,
    location_source: 'gps',
    assigned_team: 'Medical Rescue Team',
    status: 'RESPONDER_ACCEPTED',
    assigned_responders: [
      {
        responder_id: 'RSP-001',
        name: 'Arun Kumar',
        role: 'Swift Water & Flood Rescue',
        team: 'Rescue Squad Alpha',
        is_primary: true,
        status: 'Accepted',
        assigned_at: new Date(Date.now() - 1000 * 60 * 20),
        accepted_at: new Date(Date.now() - 1000 * 60 * 18)
      }
    ],
    created_at: new Date(Date.now() - 1000 * 60 * 25)
  },
  {
    emergency_id: 'RQ-20261007-F14C',
    user_id: 'victim_demo_3',
    emergency_type: 'Fire',
    severity: 'High - Industrial Chemical Leak',
    priority: 'P2',
    people_affected: 8,
    message: 'Smoke dense in warehouse B. Workers assembled at muster point.',
    latitude: 12.6937,
    longitude: 79.9757,
    location_source: 'gps',
    assigned_team: 'Fire Rescue Team',
    status: 'RESPONDER_ASSIGNED',
    assigned_responders: [
      {
        responder_id: 'RSP-005',
        name: 'Karthik N',
        role: 'Fire & Hazmat Specialist',
        team: 'Fire Rescue Team',
        is_primary: true,
        status: 'Assigned',
        assigned_at: new Date(Date.now() - 1000 * 60 * 30)
      }
    ],
    created_at: new Date(Date.now() - 1000 * 60 * 35)
  }
];

async function seed() {
  try {
    console.log('🔄 Connecting to MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log(`✅ Connected to database: ${mongoose.connection.name}`);

    // 1. Seed or Update Users (Admin & Responders)
    for (const u of SEED_USERS) {
      const existing = await User.findOne({ email: u.email });
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(u.password, salt);

      if (existing) {
        existing.role = u.role;
        existing.responder_id = u.responder_id;
        existing.specialization = u.specialization;
        existing.team = u.team;
        existing.availability = u.availability;
        existing.password = hashedPassword;
        if (u.current_location) existing.current_location = u.current_location;
        await existing.save();
        console.log(`👤 Updated existing user: ${u.email} [Role: ${u.role}]`);
      } else {
        const newUser = new User({
          ...u,
          password: hashedPassword,
          created_at: new Date()
        });
        await newUser.save();
        console.log(`✨ Created new user: ${u.email} [Role: ${u.role}]`);
      }
    }

    // 2. Check if emergencies exist; if none, seed sample emergencies
    const emergencyCount = await Emergency.countDocuments();
    if (emergencyCount === 0) {
      console.log('📝 Seeding initial active emergencies...');
      for (const em of SAMPLE_EMERGENCIES) {
        await Emergency.create(em);
      }
      console.log(`✅ Seeded ${SAMPLE_EMERGENCIES.length} sample emergencies`);
    } else {
      console.log(`ℹ️ Emergencies already present in database: ${emergencyCount}`);
    }

    console.log('\n🎉 Database provisioning complete!');
    console.log('📋 Login Credentials:');
    console.log('  ADMIN:     admin@resqnet.com     / admin123');
    console.log('  RESPONDER: responder@resqnet.com / responder123');
    console.log('  VICTIM:    Register via public form or use existing victim account\n');

    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding failed:', err);
    process.exit(1);
  }
}

seed();

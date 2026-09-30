# ResQNet Victim Mobile App

Offline-first Flutter emergency-response mobile application for the ResQNet communication platform, upgraded and styled after the ResQNet Beacon system.

---

## Key Features & Capabilities

### 1. Emergency Visual Design Language
- **Dark Emergency Response Theme**: Charcoal-navy foundation (`#0E131B`), dark elevated surfaces (`#161C26`, `#202938`), emergency red accents (`#DC2626`), success green (`#22C55E`), warning amber (`#F59E0B`), and info blue (`#38BDF8`).
- **Typography & Touch Targets**: Clear uppercase tracking labels (`label-caps`), high contrast, large emergency touch controls, and accessible status chips.
- **Pulsing SOS Orb**: Dominant animated circular SOS control with subtle glow and confirmation flow.

### 2. Full 5-Tab Navigation System
1. **Home**: Live status strip (GPS, Mesh, Nodes, Battery), active SOS banner, central SOS Orb, quick action grid, device & link status summary.
2. **Messages**: Victim ↔ Responder messaging, offline queue with automatic backoff and retry, quick-response pills ("I am safe", "I am injured", "I need medical help", etc.), character-capped emergency composer.
3. **Location**: Live GPS satellite coordinates, accuracy (±m), recorded timestamp, radar grid canvas with pinging map marker, and one-tap location broadcasting.
4. **Network**: Off-grid mesh status, nearby relay nodes (Alpha, Bravo, Charlie) with signal strength bars, message queue buffer, and rescan trigger.
5. **Profile**: Personal information, device identity chips, and navigation to Medical Profile, Emergency Contacts, BLE Handheld Link, Incident History, and Onboarding guide.

### 3. Comprehensive SOS Flow
- **Emergency Types**: Flood, Cyclone, Earthquake, Fire, Medical, Road Accident, Missing Person, Safety / Crime, Other.
- **Severity Levels**: Critical (Life Threat), Serious (High Hazard), Urgent (Assistance), General (Support).
- **People Affected**: 1, 2, 3, 4, 5+.
- **Automatic Deterministic Priority**: P1 (Critical), P2 (Serious), P3 (Urgent), P4 (General).
- **Situation Details**: Optional 140-character situation note.
- **Pre-send Summary**: Live review of type, severity, priority, coordinates, accuracy, battery, and relay channel.

### 4. SOS Active & Real-Time Tracking Screen
- Visually dominant active emergency banner.
- **7-Stage Delivery Timeline**:
  1. Request Created (local)
  2. GPS Location Captured
  3. BLE Transmission
  4. LoRa Mesh Relaying
  5. Gateway Confirmation
  6. Responder Notification
  7. Responder Assigned
- **Visual Communication Path Card**: Demonstrates each hop from victim phone to commander dashboard.
- Live responder dispatch status ("REQUESTED", "RECEIVED", "ACKNOWLEDGED", "TEAM ASSIGNED", "EN ROUTE", "ARRIVED", "RESCUED", "CLOSED").
- Direct access to message thread and safe SOS cancellation with confirmation.

### 5. Offline-First Resilience
- **Zero Internet Requirement**: SOS creation saves locally immediately before transmission.
- **Restart Recovery**: Incomplete transmissions survive app termination and restore to queued state on reboot.
- **Deduplication & Anti-Flooding**: Repeated alerts within a 10-minute/location window consolidate into the same `emergencyId`, incrementing `repeatedCount` and auto-updating location without flooding the LoRa mesh.
- **Compact SOS Packet**: Strictly emergency-critical data (`emergency_id`, `priority`, `type`, `severity`, `lat`, `lng`, `accuracy`, `people`, `battery`, `ttl`). Full medical records are never leaked over LoRa.

### 6. Medical Profile & Emergency Contacts
- **Medical Details**: Blood group, age, allergies, conditions, medications. Stored locally; retrieved by authorized responders through cloud API once gateway is reached.
- **Emergency Contacts**: Multiple contacts (Name, Relationship, Phone). Automatically alerted once gateway connectivity is achieved.

### 7. Simulation Mode & Hardware Abstraction
- Clearly marked with `SIMULATION MODE` badges when physical ESP32 SX1262 LoRa modules are not connected.
- Real hardware states are never faked.
- Ready for plug-and-play ESP32 BLE characteristic UUID integration.

---

## End-to-End Architecture

```
Victim Phone (Flutter)
       │ (BLE compact packet)
       ▼
LoRa Handheld (ESP32 + SX1262)
       │ (Sub-GHz radio mesh)
       ▼
LoRa Multi-Hop Mesh (Node-to-Node)
       │ (Perimeter bridge)
       ▼
ResQNet Gateway Edge
       │ (HTTP / WebSocket)
       ▼
FastAPI Backend
       │ (Authorized storage)
       ▼
MongoDB Atlas & Responder Command Center
```

*Note: MongoDB credentials remain strictly on the FastAPI server and are never included in the mobile client.*

---

## Verification & Commands

From `E:\downloads\ResQNet_Victim_App\ResQNet_Victim_App`, run:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

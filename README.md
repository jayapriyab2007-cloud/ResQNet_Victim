# ResQNet — Victim Application

The official victim-side application for the **ResQNet** emergency assistance and disaster response network.

## Purpose

ResQNet connects citizens facing critical emergencies (floods, fires, earthquakes, accidents, medical crises) with automated emergency dispatch routing, live GPS telemetry, real-time rescue unit tracking, and offline distress signaling.

## Technology Stack

- **Frontend**: React (Vite)
- **Styling**: Vanilla CSS (Mobile-First Emergency Design System)
- **Mapping**: Leaflet + OpenStreetMap
- **Telemetry**: Browser Geolocation API
- **Offline Storage**: LocalStorage Emergency Queue & Network Status Listeners
- **Future Backend**: Node.js + Express
- **Future Database**: MongoDB Atlas
- **Future Real-time**: Socket.IO

## Project Structure

```text
ResQNet-Victim/
│
├── client/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   └── style.css
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
│
├── server/
│   └── package.json
│
├── .gitignore
└── README.md
```

## How to Run

1. Navigate to the client directory:
   ```bash
   cd client
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the Vite development server:
   ```bash
   npm run dev
   ```
4. Open the displayed URL (default: `http://localhost:3000`) in your browser or mobile viewport.

## Current Frontend Features

1. **Onboarding Experience (Pre-Authentication)**:
   - **Welcome**: ResQNet brand beacon, distress assistance tagline, and `Get Started` trigger.
   - **What is ResQNet?**: Core pillars (`Location Aware`, `One-Tap SOS`, `Connected Rescue`) explaining the automated rescue bridge.
   - **How It Works**: Visual pipeline (`Raise SOS` → `Location Detected` → `Emergency Routed` → `Responder Assigned` → `Track & Communicate`) featuring the strict principle: *“You don't choose the responder. ResQNet routes your emergency to the appropriate team.”*
   - **Features**: Showcase of the 8 disaster and safety response capabilities.
   - **Authentication Choice**: Sign In / Create Account / Quick Demo Sign In. Users cannot directly enter the Home dashboard without authenticating.
2. **Authentication Flow**: Account login & registration with blood group and emergency contact validation (persisted in local state).
3. **Emergency Home**: Instant critical SOS trigger and 10 disaster emergency categories (Flood, Cyclone, Earthquake, Fire, Forest Fire, Tsunami, Landslide, Medical Emergency, Safety/Crime, Other).
4. **Emergency Details**: Severity selection (Low, Medium, High, Critical), victim count, optional details, and automated GPS detection.
5. **Instant Notification / Snackbar**: Displays `✅ Emergency message sent` upon triggering SOS and automatically redirects to Live Status.
6. **Live Status Screen**:
   - Emergency overview & acknowledgement.
   - Status timeline: `✓ Emergency Sent` → `✓ Location Shared` → `○ Emergency Team Notified` → `○ Responder Assignment Pending` (and `● Responder On the Way` when assigned).
   - Embedded Leaflet + OpenStreetMap rendering the victim's actual GPS location.
   - "Waiting for responder assignment" state (no fake responders by default).
   - Responder unit details & route tracking once assigned.
   - Direct responder Chat (locked until responder assignment).
   - Interactive simulation toggle for testing and college/SIH judge demonstrations.
7. **Responder Communication**: Two-way chat stream with the assigned rescue lead (unlocked only after assignment).
8. **Emergency History**: Log of past emergency events with detailed modal inspection.
9. **Victim Profile**: Editable personal, contact, and blood group information.
10. **Distinct Offline & GPS Support**: Distinguishes internet connectivity from GPS availability; queues distress signals locally when offline (`🔴 Offline — GPS Available`).

## Bottom Navigation Structure

```text
Home (Create) | Live Status (Monitor) | History (Past) | Profile (Info)
```

## Future Backend Integration

In the subsequent development stage, the client connects to:
- `POST /api/register` & `POST /api/login` (Auth)
- `POST /api/emergencies` (SOS submission)
- `GET /api/emergencies/:id` & `GET /api/history/:victimId` (Status & Logs)
- `Socket.IO` (Live responder location updates, real-time status transitions, and duplex chat)
- MongoDB Atlas (Secure persistent collections for victims, emergencies, and notifications)

# ResQNet Victim App – implementation notes

## Real emergency path
1. Victim creates SOS.
2. App requests GPS.
3. App calculates P1-P4 locally.
4. App stores the emergency locally.
5. App creates a compact packet.
6. App transfers the packet over BLE to the ResQNet handheld.
7. Handheld/mesh firmware is responsible for LoRa queueing, ACK, retries, duplicate filtering, TTL and multi-hop forwarding.
8. A gateway forwards to FastAPI when Internet is available.
9. FastAPI persists to MongoDB Atlas and dispatches the incident to the correct responder/facility based on emergency type and location.

## Dispatch mapping expected by backend
- FLOOD -> disaster/rescue team
- CYCLONE -> disaster/rescue team
- EARTHQUAKE -> disaster rescue + medical support
- FIRE -> fire station + rescue team
- MEDICAL -> nearest suitable hospital + rescue/medical team
- ACCIDENT -> rescue team + hospital
- MISSING_PERSON -> search/rescue
- SAFETY -> appropriate safety/security responder

## Next production tasks
- Implement JWT authentication against the existing FastAPI backend.
- Align `/emergencies` request/response schemas.
- Add real ESP32 BLE service/characteristic UUIDs.
- Add packet signing/encryption at the handheld protocol layer.
- Add background GPS policy appropriate for Android.
- Add Android battery/network state.
- Add offline map tiles and local routing only if needed on victim side; detailed safest-route computation belongs to responder side.
- Add end-to-end integration tests with gateway simulator.

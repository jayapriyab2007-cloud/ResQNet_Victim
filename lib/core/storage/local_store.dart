import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';
import '../../models/contact.dart';
import '../../models/message.dart';

class LocalStore {
  static const _profile = 'profile';
  static const _emergencies = 'emergencies';
  static const _loggedIn = 'logged_in';
  static const _token = 'token';
  static const _contacts = 'contacts';
  static const _messages = 'messages';
  static const _onboarded = 'onboarded';
  static const _activeEmergencyId = 'active_emergency_id';
  static const _activeEmergencyIds = 'active_emergency_ids';
  static const _lastLat = 'last_lat';
  static const _lastLng = 'last_lng';
  static const _lastAcc = 'last_acc';
  static const _lastLocTime = 'last_loc_time';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // Profile
  Future<void> saveProfile(UserProfile p) async =>
      (await _prefs).setString(_profile, jsonEncode(p.toJson()));

  Future<UserProfile?> loadProfile() async {
    final s = (await _prefs).getString(_profile);
    return s == null ? null : UserProfile.fromJson(jsonDecode(s));
  }

  // Session
  Future<void> setSession({required bool loggedIn, String? token}) async {
    final p = await _prefs;
    await p.setBool(_loggedIn, loggedIn);
    if (token != null) await p.setString(_token, token);
  }

  Future<bool> isLoggedIn() async => (await _prefs).getBool(_loggedIn) ?? false;
  Future<String?> token() async => (await _prefs).getString(_token);

  // Onboarding
  Future<bool> isOnboarded() async => (await _prefs).getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) async => (await _prefs).setBool(_onboarded, v);

  // Active Emergency tracking
  Future<String?> getActiveEmergencyId() async {
    final ids = await getActiveEmergencyIds();
    return ids.isNotEmpty ? ids.first : null;
  }

  Future<void> setActiveEmergencyId(String? id) async {
    if (id == null) {
      await setActiveEmergencyIds([]);
    } else {
      await setActiveEmergencyIds([id]);
    }
  }

  Future<List<String>> getActiveEmergencyIds() async {
    final p = await _prefs;
    final list = p.getStringList(_activeEmergencyIds);
    if (list != null && list.isNotEmpty) return list;
    final single = p.getString(_activeEmergencyId);
    return single != null ? [single] : [];
  }

  Future<void> setActiveEmergencyIds(List<String> ids) async {
    final p = await _prefs;
    await p.setStringList(_activeEmergencyIds, ids);
    if (ids.isNotEmpty) {
      await p.setString(_activeEmergencyId, ids.first);
    } else {
      await p.remove(_activeEmergencyId);
    }
  }

  Future<void> addActiveEmergencyId(String id) async {
    final current = await getActiveEmergencyIds();
    if (!current.contains(id)) {
      final updated = [...current, id];
      await setActiveEmergencyIds(updated);
    }
  }

  Future<void> removeActiveEmergencyId(String id) async {
    final current = await getActiveEmergencyIds();
    final updated = current.where((x) => x != id).toList();
    await setActiveEmergencyIds(updated);
  }

  // Emergencies
  Future<List<Emergency>> loadEmergencies() async {
    final raw = (await _prefs).getStringList(_emergencies) ?? [];
    return raw.map((x) => Emergency.fromJson(jsonDecode(x))).toList();
  }

  Future<void> saveEmergency(Emergency e) async {
    final p = await _prefs;
    final all = await loadEmergencies();
    final index = all.indexWhere((x) => x.emergencyId == e.emergencyId);
    if (index >= 0) {
      all[index] = e;
    } else {
      all.insert(0, e);
    }
    await p.setStringList(
      _emergencies,
      all.map((x) => jsonEncode(x.toJson())).toList(),
    );
  }

  // Contacts
  Future<List<EmergencyContact>> loadContacts() async {
    final raw = (await _prefs).getStringList(_contacts);
    if (raw == null || raw.isEmpty) {
      // Default initial contact
      return const [
        EmergencyContact(
          id: 'def-1',
          name: 'Disaster Emergency Control',
          relation: 'National Response Center',
          phone: '112 / 1070',
        ),
      ];
    }
    return raw.map((x) => EmergencyContact.fromJson(jsonDecode(x))).toList();
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final p = await _prefs;
    await p.setStringList(
      _contacts,
      contacts.map((x) => jsonEncode(x.toJson())).toList(),
    );
  }

  // Messages (Offline-first message queue)
  Future<List<EmergencyMessage>> loadMessages() async {
    final raw = (await _prefs).getStringList(_messages) ?? [];
    final list = raw.map((x) => EmergencyMessage.fromJson(jsonDecode(x))).toList();

    // App restart recovery: restore any incomplete transmissions to queued
    bool changed = false;
    final recovered = list.map((m) {
      if (m.from == 'me' && (m.status == MessageStatus.relaying || m.status == MessageStatus.failed)) {
        changed = true;
        return m.copyWith(status: MessageStatus.queued);
      }
      return m;
    }).toList();

    if (changed) {
      await saveMessages(recovered);
    }
    return recovered;
  }

  Future<void> saveMessages(List<EmergencyMessage> messages) async {
    final p = await _prefs;
    await p.setStringList(
      _messages,
      messages.map((x) => jsonEncode(x.toJson())).toList(),
    );
  }

  // Location Fallback
  Future<void> saveLastLocation(double lat, double lng, double accuracy) async {
    final p = await _prefs;
    await p.setDouble(_lastLat, lat);
    await p.setDouble(_lastLng, lng);
    await p.setDouble(_lastAcc, accuracy);
    await p.setString(_lastLocTime, DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> loadLastLocation() async {
    final p = await _prefs;
    final lat = p.getDouble(_lastLat);
    final lng = p.getDouble(_lastLng);
    final acc = p.getDouble(_lastAcc);
    final timeStr = p.getString(_lastLocTime);
    if (lat != null && lng != null) {
      return {
        'latitude': lat,
        'longitude': lng,
        'accuracy': acc ?? 15.0,
        'timestamp': DateTime.tryParse(timeStr ?? '') ?? DateTime.now(),
      };
    }
    return null;
  }
}

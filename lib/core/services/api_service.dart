import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../models/emergency.dart';
import '../../models/user_profile.dart';

class ApiService {
  final String baseUrl;
  ApiService({this.baseUrl = AppConstants.apiBaseUrl});

  Future<bool> health() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 3));
      return r.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // Auth endpoints
  Future<Map<String, dynamic>?> login({required String identifier, required String password}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': identifier, 'password': password}),
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Profile endpoints
  Future<bool> updateProfile(UserProfile profile, {String? token}) async {
    try {
      final r = await http.patch(
        Uri.parse('$baseUrl/victims/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profile.toJson()),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Emergency endpoints
  Future<bool> syncEmergency(Emergency e, {String? token}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/emergencies'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(e.toJson()),
      ).timeout(const Duration(seconds: 6));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> patchEmergency(String emergencyId, Map<String, dynamic> patch, {String? token}) async {
    try {
      final r = await http.patch(
        Uri.parse('$baseUrl/emergencies/$emergencyId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(patch),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelEmergency(String emergencyId, {String? token}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/emergencies/$emergencyId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLocation(String emergencyId, double lat, double lng, {String? token}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/emergencies/$emergencyId/location'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lng}),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getMyEmergencies({String? token}) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/emergencies/my'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final decoded = jsonDecode(r.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getEmergencyById(String emergencyId, {String? token}) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/emergencies/$emergencyId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

import 'package:geolocator/geolocator.dart';
import '../storage/local_store.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isLive; // true = satellite fix, false = last known fallback

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.isLive,
  });
}

class LocationService {
  final LocalStore? store;
  LocationService({this.store});

  Future<bool> isGpsAvailable() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
      final perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
      if (store != null) {
        await store!.saveLastLocation(pos.latitude, pos.longitude, pos.accuracy);
      }
      return pos;
    } catch (_) {
      return null;
    }
  }

  Future<LocationResult?> getPositionWithFallback() async {
    final live = await getCurrentPosition();
    if (live != null) {
      return LocationResult(
        latitude: live.latitude,
        longitude: live.longitude,
        accuracy: live.accuracy,
        timestamp: live.timestamp,
        isLive: true,
      );
    }

    // Try device's cached last known position
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        if (store != null) {
          await store!.saveLastLocation(cached.latitude, cached.longitude, cached.accuracy);
        }
        return LocationResult(
          latitude: cached.latitude,
          longitude: cached.longitude,
          accuracy: cached.accuracy,
          timestamp: cached.timestamp,
          isLive: false,
        );
      }
    } catch (_) {}

    // Fall back to local persistent store
    if (store != null) {
      final stored = await store!.loadLastLocation();
      if (stored != null) {
        return LocationResult(
          latitude: stored['latitude'] as double,
          longitude: stored['longitude'] as double,
          accuracy: stored['accuracy'] as double,
          timestamp: stored['timestamp'] as DateTime,
          isLive: false,
        );
      }
    }

    return null; // Truly no location available (do not fabricate)
  }
}

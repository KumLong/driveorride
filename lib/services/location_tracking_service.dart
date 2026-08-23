import 'dart:async';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

/// GPS tracking for the Trip In Progress (Drive) screen.
/// Matches the exact pattern from Practical 13 — uses `location` and
/// `permission_handler` packages, NOT geolocator.
class LocationTrackingService {
  final Location _location = Location();
  StreamSubscription<LocationData>? _subscription;

  Future<bool> isPermissionGranted() async {
    return await handler.Permission.locationWhenInUse.isGranted;
  }

  Future<bool> isGpsEnabled() async {
    return await handler.Permission.location.serviceStatus.isEnabled;
  }

  Future<void> requestLocationPermission() async {
    await handler.Permission.locationWhenInUse.request();
  }

  Future<bool> requestEnableGps() async {
    final enabled = await isGpsEnabled();
    if (enabled) return true;
    return await _location.requestService();
  }

  /// Starts streaming the user's live position — used to draw the
  /// "you are here" moving dot on the Trip In Progress (Drive) map.
  void startTracking(void Function(LocationData) onUpdate) {
    _subscription = _location.onLocationChanged.listen(onUpdate);
  }

  void stopTracking() {
    _subscription?.cancel();
  }
}

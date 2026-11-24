import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

/// Reasons why location capture may fail
enum LocationFailureReason {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  timeout,
  unavailable,
}

/// Holds the result of a GPS location capture attempt
class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? capturedAt; // device-local ISO 8601 timestamp
  final bool isWithinGeofence;
  final double? distanceToOfficeMeters;
  final LocationFailureReason? failure;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.capturedAt,
    this.isWithinGeofence = false,
    this.distanceToOfficeMeters,
    this.failure,
  });

  bool get isSuccess => failure == null && latitude != null && longitude != null;

  String get failureMessage {
    switch (failure) {
      case LocationFailureReason.permissionDenied:
        return 'Location permission was denied. Attendance will be recorded without location data.';
      case LocationFailureReason.permissionPermanentlyDenied:
        return 'Location permission is permanently denied. Please enable it in device settings.';
      case LocationFailureReason.serviceDisabled:
        return 'Location services are disabled. Please enable GPS and try again.';
      case LocationFailureReason.timeout:
        return 'Location request timed out. Attendance recorded without location data.';
      case LocationFailureReason.unavailable:
        return 'Location is currently unavailable. Attendance recorded without location data.';
      case null:
        return '';
    }
  }

  @override
  String toString() =>
      'LocationResult(lat: $latitude, lng: $longitude, '
      'accuracy: $accuracy, withinGeofence: $isWithinGeofence, '
      'distance: $distanceToOfficeMeters, failure: $failure)';
}

/// Service responsible for capturing GPS location and validating geofence
class LocationService {
  /// Office coordinates and radius read from [AppConstants]
  static const double _officeLat = AppConstants.defaultOfficeLatitude;
  static const double _officeLng = AppConstants.defaultOfficeLongitude;
  static const double _radiusMeters = AppConstants.defaultGeofenceRadiusMeters;
  static const int _timeoutSeconds = AppConstants.locationTimeoutSeconds;

  /// Captures the employee's current GPS location and validates office geofence.
  ///
  /// Returns a [LocationResult] with location data on success, or with a
  /// [LocationFailureReason] when any error occurs — this method never throws.
  Future<LocationResult> captureCheckInLocation() async {
    try {
      // 1. Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled.');
        return const LocationResult(failure: LocationFailureReason.serviceDisabled);
      }

      // 2. Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. Request permission if not yet granted
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied after request.');
          return const LocationResult(failure: LocationFailureReason.permissionDenied);
        }
      }

      // 4. Handle permanently denied (user must open device settings)
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied.');
        return const LocationResult(failure: LocationFailureReason.permissionPermanentlyDenied);
      }

      // 5. Fetch current position with timeout guard
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: _timeoutSeconds),
        ),
      );

      // 6. Calculate distance from office to determine geofence status
      final distanceMeters = Geolocator.distanceBetween(
        _officeLat,
        _officeLng,
        position.latitude,
        position.longitude,
      );
      final isWithinGeofence = distanceMeters <= _radiusMeters;

      final capturedAt = position.timestamp.toIso8601String();

      debugPrint(
        '[LocationService] Location captured: '
        '(${position.latitude}, ${position.longitude}), '
        'accuracy=${position.accuracy}m, '
        'distance=${distanceMeters.toStringAsFixed(1)}m, '
        'within=$isWithinGeofence',
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: capturedAt,
        isWithinGeofence: isWithinGeofence,
        distanceToOfficeMeters: distanceMeters,
      );
    } on LocationServiceDisabledException {
      debugPrint('[LocationService] LocationServiceDisabledException caught.');
      return const LocationResult(failure: LocationFailureReason.serviceDisabled);
    } on PermissionDeniedException {
      debugPrint('[LocationService] PermissionDeniedException caught.');
      return const LocationResult(failure: LocationFailureReason.permissionDenied);
    } on TimeoutException {
      debugPrint('[LocationService] Location request timed out.');
      return const LocationResult(failure: LocationFailureReason.timeout);
    } catch (e) {
      debugPrint('[LocationService] Unexpected error: $e');
      return const LocationResult(failure: LocationFailureReason.unavailable);
    }
  }
}

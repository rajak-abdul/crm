import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request location permission
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    debugPrint("GPS Enabled: $serviceEnabled");

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    debugPrint("Current Permission: $permission");

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      debugPrint("Permission Denied");
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permission Denied Forever");
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /// Get current GPS location once
  static Future<Position> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint("Latitude : ${position.latitude}");
    debugPrint("Longitude: ${position.longitude}");
    debugPrint("Accuracy : ${position.accuracy}");

    return position;
  }

  /// Live location stream
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    );
  }
}
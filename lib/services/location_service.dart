import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    debugPrint("Step 1");

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint("Service Enabled: $serviceEnabled");

    if (!serviceEnabled) {
      debugPrint("GPS is OFF");
      await Geolocator.openLocationSettings();
      return false;
    }

    debugPrint("Step 2");

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint("Current Permission: $permission");

    if (permission == LocationPermission.denied) {
      debugPrint("Requesting permission...");
      permission = await Geolocator.requestPermission();
      debugPrint("Permission after request: $permission");
    }

    if (permission == LocationPermission.denied) {
      debugPrint("Permission denied");
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permission denied forever");
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  static Future<Position> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint("Latitude : ${position.latitude}");
    debugPrint("Longitude: ${position.longitude}");
    debugPrint("Accuracy : ${position.accuracy}");

    return position;
  }
}
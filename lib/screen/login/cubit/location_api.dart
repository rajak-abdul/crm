import 'dart:async';

import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/services/location_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationApiService {
  static StreamSubscription<Position>? _locationSubscription;

  /// Call this after login
  static Future<void> startLiveLocation() async {
    final hasPermission = await LocationService.requestPermission();

    if (!hasPermission) {
      debugPrint("Location permission denied");
      return;
    }

    // Stop previous listener if already running
    await _locationSubscription?.cancel();

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // Update after moving 20 meters
      ),
    ).listen(
      (Position position) async {
        await _sendLocation(position);
      },
      onError: (e) {
        debugPrint("Location Stream Error: $e");
      },
    );

    debugPrint("Live Location Tracking Started");
  }

  /// Call this on logout
  static Future<void>stopLiveLocation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    debugPrint("Live Location Tracking Stopped");
  }

  static Future<void> _sendLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString("token");
      final slug = prefs.getString("tenant_slug");

      if (token == null || slug == null) {
        debugPrint("Token or slug missing");
        return;
      }

      final dio = Dio()..interceptors.add(AuthInterceptor());

      final response = await dio.post(
        "https://crm-backend-api.techzarinfo.cloud/$slug/api/location/update",
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "accuracy": position.accuracy,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        ),
      );

      debugPrint("============== LOCATION UPDATED ==============");
      debugPrint("Latitude  : ${position.latitude}");
      debugPrint("Longitude : ${position.longitude}");
      debugPrint("Accuracy  : ${position.accuracy}");
      debugPrint("Response  : ${response.data}");
      debugPrint("==============================================");
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }
}
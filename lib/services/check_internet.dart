import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkGuard {
  static Future<bool> isOnline(BuildContext context) async {
    final result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You are offline. Only Dashboard is available.",
          ),
        ),
      );

      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );

      return false;
    }

    return true;
  }
}

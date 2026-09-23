import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// Entry point for the background service isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  // Initial location fetch and continuous repeat handler
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[BackgroundService] onStart triggered by $starter at $timestamp');
    await _fetchAndUploadLocation();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    debugPrint('[BackgroundService] onRepeatEvent triggered at $timestamp');
    await _fetchAndUploadLocation();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isStopped) async {
    debugPrint('[BackgroundService] onDestroy at $timestamp, isStopped: $isStopped');
  }

  Future<void> _fetchAndUploadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final acc = position.accuracy;
      final time = DateTime.now();

      debugPrint('[BackgroundService] Acquired GPS: lat=$lat, lng=$lng, acc=$acc');

      // Update notification content
      FlutterForegroundTask.updateService(
        notificationTitle: 'Location sharing is active',
        notificationText: 'Your location is being shared in the background.',
      );

      // Upload directly to backend
      final url = Uri.parse(AppConfig.locationApiUrl);
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': lat,
              'longitude': lng,
              'accuracy': acc,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[BackgroundService] Backend upload HTTP status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Cache last uploaded location
        await AppConfig.saveLastLocation(
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          timestamp: time,
        );

        // Send data back to the UI isolate if the app is currently open
        FlutterForegroundTask.sendDataToMain({
          'latitude': lat,
          'longitude': lng,
          'accuracy': acc,
          'timestamp': time.toIso8601String(),
          'success': true,
        });
      } else {
        FlutterForegroundTask.sendDataToMain({
          'latitude': lat,
          'longitude': lng,
          'accuracy': acc,
          'timestamp': time.toIso8601String(),
          'success': false,
          'error': 'Server error: HTTP ${response.statusCode}',
        });
      }
    } on SocketException catch (_) {
      debugPrint('[BackgroundService] Internet unavailable');
      FlutterForegroundTask.sendDataToMain({
        'success': false,
        'error': 'Internet unavailable. Last upload failed.',
      });
    } catch (e) {
      debugPrint('[BackgroundService] Location fetch or upload error: $e');
      FlutterForegroundTask.sendDataToMain({
        'success': false,
        'error': 'Upload failed: $e',
      });
    }
  }
}

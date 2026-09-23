import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyBaseUrl = 'sender_backend_url';
  static const String _keyUpdateIntervalSec = 'sender_update_interval_sec';
  static const String _keySetupCompleted = 'locationSetupCompleted';
  static const String _keyLastLat = 'sender_last_lat';
  static const String _keyLastLng = 'sender_last_lng';
  static const String _keyLastAcc = 'sender_last_acc';
  static const String _keyLastTime = 'sender_last_time';

  // Production Render deployed backend URL
  static const String defaultBaseUrl = 'https://location-9ql3.onrender.com';

  // Default to 15 minutes per requirement, configurable down to seconds or minutes
  static const int defaultUpdateIntervalSeconds = 15 * 60; // 900 seconds (15 minutes)

  static String _baseUrl = defaultBaseUrl;
  static int _updateIntervalSeconds = defaultUpdateIntervalSeconds;
  static bool _locationSetupCompleted = false;

  static String get baseUrl => _baseUrl;
  static int get updateIntervalSeconds => _updateIntervalSeconds;
  static int get updateIntervalMinutes => (_updateIntervalSeconds / 60).ceil();
  static bool get locationSetupCompleted => _locationSetupCompleted;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl == null || savedUrl.contains('10.0.2.2') || savedUrl.contains('localhost')) {
      _baseUrl = defaultBaseUrl;
      await prefs.setString(_keyBaseUrl, _baseUrl);
    } else {
      _baseUrl = savedUrl;
    }
    _updateIntervalSeconds = prefs.getInt(_keyUpdateIntervalSec) ?? defaultUpdateIntervalSeconds;
    _locationSetupCompleted = prefs.getBool(_keySetupCompleted) ?? false;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrl);
  }

  static Future<void> setUpdateIntervalSeconds(int seconds) async {
    if (seconds < 5) seconds = 5;
    _updateIntervalSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUpdateIntervalSec, _updateIntervalSeconds);
  }

  static Future<void> setUpdateIntervalMinutes(int minutes) async {
    await setUpdateIntervalSeconds(minutes * 60);
  }

  static Future<void> setLocationSetupCompleted(bool completed) async {
    _locationSetupCompleted = completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupCompleted, completed);
  }

  static Future<void> saveLastLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLastLat, latitude);
    await prefs.setDouble(_keyLastLng, longitude);
    await prefs.setDouble(_keyLastAcc, accuracy);
    await prefs.setString(_keyLastTime, timestamp.toIso8601String());
  }

  static Future<Map<String, dynamic>?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLastLat);
    final lng = prefs.getDouble(_keyLastLng);
    final acc = prefs.getDouble(_keyLastAcc);
    final timeStr = prefs.getString(_keyLastTime);
    if (lat != null && lng != null && acc != null && timeStr != null) {
      return {
        'latitude': lat,
        'longitude': lng,
        'accuracy': acc,
        'timestamp': DateTime.tryParse(timeStr) ?? DateTime.now(),
      };
    }
    return null;
  }

  static String get locationApiUrl => '$_baseUrl/api/location';
  static String get healthApiUrl => '$_baseUrl/api/health';
}

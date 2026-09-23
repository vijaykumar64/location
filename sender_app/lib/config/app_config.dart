import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyBaseUrl = 'sender_backend_url';
  static const String _keyUpdateIntervalSec = 'sender_update_interval_sec';

  // Production Render deployed backend URL
  static const String defaultBaseUrl = 'https://location-9ql3.onrender.com';

  // Default to 5 seconds for continuous real-time sending without break
  static const int defaultUpdateIntervalSeconds = 5;

  static String _baseUrl = defaultBaseUrl;
  static int _updateIntervalSeconds = defaultUpdateIntervalSeconds;

  static String get baseUrl => _baseUrl;
  static int get updateIntervalSeconds => _updateIntervalSeconds;
  static int get updateIntervalMinutes => (_updateIntervalSeconds / 60).ceil();

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
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrl);
  }

  static Future<void> setUpdateIntervalSeconds(int seconds) async {
    if (seconds < 1) seconds = 1;
    _updateIntervalSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUpdateIntervalSec, _updateIntervalSeconds);
  }

  static Future<void> setUpdateIntervalMinutes(int minutes) async {
    await setUpdateIntervalSeconds(minutes * 60);
  }

  static String get locationApiUrl => '$_baseUrl/api/location';
  static String get healthApiUrl => '$_baseUrl/api/health';
}

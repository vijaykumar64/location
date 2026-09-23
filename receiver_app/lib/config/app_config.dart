import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyBaseUrl = 'receiver_backend_url';

  // Default to Android emulator host loopback address
  // For physical devices, set to your computer's local IP (e.g., http://192.168.1.10:5000)
  static const String defaultBaseUrl = 'http://10.0.2.2:5000';

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrl);
  }

  static String get locationApiUrl => '$_baseUrl/api/location';
  static String get healthApiUrl => '$_baseUrl/api/health';
  static String get socketUrl => _baseUrl;
}

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyBaseUrl = 'receiver_backend_url';

  // Production Render deployed backend URL
  static const String defaultBaseUrl = 'https://location-9ql3.onrender.com';

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl == null || savedUrl.contains('10.0.2.2') || savedUrl.contains('localhost')) {
      _baseUrl = defaultBaseUrl;
      await prefs.setString(_keyBaseUrl, _baseUrl);
    } else {
      _baseUrl = savedUrl;
    }
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

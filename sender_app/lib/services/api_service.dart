import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/location_data.dart';

class ApiException implements Exception {
  final String message;
  final bool isNetworkError;

  ApiException(this.message, {this.isNetworkError = false});

  @override
  String toString() => message;
}

class ApiService {
  /// Upload current coordinates to the backend
  /// POST /api/location
  static Future<LocationDataModel> uploadLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final url = Uri.parse(AppConfig.locationApiUrl);

    final payload = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return LocationDataModel.fromJson(data);
      } else {
        throw ApiException('Server error: HTTP ${response.statusCode}');
      }
    } on SocketException catch (_) {
      throw ApiException('Internet unavailable. Last upload failed.', isNetworkError: true);
    } on TimeoutException catch (_) {
      throw ApiException('Connection timed out. Last upload failed.', isNetworkError: true);
    } on http.ClientException catch (_) {
      throw ApiException('Unable to connect to server. Last upload failed.', isNetworkError: true);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiService] Unexpected error: $e');
      throw ApiException('Upload failed: $e');
    }
  }

  /// Ping the backend to check connectivity
  /// GET /api/health
  static Future<bool> checkHealth() async {
    try {
      final url = Uri.parse(AppConfig.healthApiUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

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
  final bool isNotFound;

  ApiException(this.message, {this.isNetworkError = false, this.isNotFound = false});

  @override
  String toString() => message;
}

class ApiService {
  /// Fetch latest location for X
  /// GET /api/location
  static Future<LocationDataModel> fetchLatestLocation() async {
    final url = Uri.parse(AppConfig.locationApiUrl);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return LocationDataModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw ApiException(
          'No location available for X yet. Waiting for X to start sharing.',
          isNotFound: true,
        );
      } else {
        throw ApiException('Server error: HTTP ${response.statusCode}');
      }
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to server.', isNetworkError: true);
    } on TimeoutException catch (_) {
      throw ApiException('Connection timed out.', isNetworkError: true);
    } on http.ClientException catch (_) {
      throw ApiException('Unable to connect to server.', isNetworkError: true);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiService] Unexpected error: $e');
      throw ApiException('Failed to fetch location: $e');
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

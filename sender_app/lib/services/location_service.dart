import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../models/location_data.dart';

enum SharingStatus {
  initializing,
  active,
  gpsDisabled,
  permissionRequired,
  permissionPermanentlyDenied,
}

class LocationService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.locationsharing.sender/location_service');

  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  SharingStatus _status = SharingStatus.initializing;
  SharingStatus get status => _status;
  bool get isSharing => _status == SharingStatus.active;

  double? _latitude;
  double? _longitude;
  double? _accuracy;
  DateTime? _lastUpdated;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get accuracy => _accuracy;
  DateTime? get lastUpdated => _lastUpdated;

  LocationDataModel? get lastLocation {
    if (_latitude != null && _longitude != null && _accuracy != null && _lastUpdated != null) {
      return LocationDataModel(
        latitude: _latitude!,
        longitude: _longitude!,
        accuracy: _accuracy!,
        timestamp: _lastUpdated!,
      );
    }
    return null;
  }

  String? _uploadError;
  String? get uploadError => _uploadError;

  String? _permissionError;
  String? get permissionError => _permissionError;

  bool _isGpsEnabled = true;
  bool get isGpsEnabled => _isGpsEnabled;

  bool _isBatteryOptimizationRestricted = false;
  bool get isBatteryOptimizationRestricted => _isBatteryOptimizationRestricted;

  Timer? _uiRefreshTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  /// Initializes the service on app launch
  Future<void> initialize() async {
    // 1. Fetch latest coordinates recorded by native Android service
    await fetchLatestLocationFromNative();

    // 2. Listen to device GPS hardware switch (on/off)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _serviceStatusSubscription?.cancel();
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        _isGpsEnabled = (status == ServiceStatus.enabled);
        if (!_isGpsEnabled && _status == SharingStatus.active) {
          _status = SharingStatus.gpsDisabled;
          _uploadError = 'Location services (GPS) disabled on device.';
          notifyListeners();
        } else if (_isGpsEnabled && _status == SharingStatus.gpsDisabled) {
          checkAndAutoStart();
        }
      });
    }

    // 3. Check battery optimization state on Android
    await checkBatteryOptimization();

    // 4. Check permissions and auto-start native service if already granted
    await checkAndAutoStart();

    // 5. Start periodic refresh timer for UI updates while screen is active
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchLatestLocationFromNative();
    });
  }

  /// Queries the native Android service for the latest coordinates
  Future<void> fetchLatestLocationFromNative() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final dynamic res = await _channel.invokeMethod('getLatestLocation');
        if (res is Map) {
          final lat = (res['latitude'] as num?)?.toDouble();
          final lng = (res['longitude'] as num?)?.toDouble();
          final acc = (res['accuracy'] as num?)?.toDouble();
          final timeStr = res['timestamp']?.toString();

          if (lat != null && lng != null && acc != null && timeStr != null) {
            _latitude = lat;
            _longitude = lng;
            _accuracy = acc;
            _lastUpdated = DateTime.tryParse(timeStr) ?? DateTime.now();
            _uploadError = null;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('[LocationService] fetchLatestLocationFromNative error: $e');
      }
    }
  }

  /// Checks battery optimization status on Android
  Future<void> checkBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool isIgnored = await _channel.invokeMethod('isBatteryOptimizationIgnored') ?? false;
        _isBatteryOptimizationRestricted = !isIgnored;
        notifyListeners();
      } catch (e) {
        debugPrint('[LocationService] checkBatteryOptimization error: $e');
      }
    }
  }

  /// Prompts Android system battery optimization whitelist dialog
  Future<void> requestIgnoreBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('requestIgnoreBatteryOptimization');
        await Future.delayed(const Duration(seconds: 1));
        await checkBatteryOptimization();
      } catch (e) {
        debugPrint('[LocationService] requestIgnoreBatteryOptimization error: $e');
      }
    }
  }

  /// Checks permissions and automatically starts the native Android service if granted
  Future<void> checkAndAutoStart() async {
    _isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isGpsEnabled) {
      _status = SharingStatus.gpsDisabled;
      _permissionError = 'Location services are disabled on your device. Please turn on GPS.';
      notifyListeners();
      return;
    }

    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      // Permission already granted: DO NOT prompt again!
      _permissionError = null;
      await _ensureNativeServiceRunning();
      _status = SharingStatus.active;
      notifyListeners();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _status = SharingStatus.permissionPermanentlyDenied;
      _permissionError = 'Location permissions are permanently denied. Please enable them in App Settings.';
      notifyListeners();
      return;
    }

    // Permission not granted yet (first installation or revoked)
    _status = SharingStatus.permissionRequired;
    notifyListeners();
  }

  /// First installation onboarding flow: requests permissions and starts the native Android service
  Future<bool> requestPermissionsAndStart() async {
    _isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isGpsEnabled) {
      _status = SharingStatus.gpsDisabled;
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _status = SharingStatus.permissionRequired;
      _permissionError = 'Location permission is required to share your coordinates with Receiver Y.';
      notifyListeners();
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _status = SharingStatus.permissionPermanentlyDenied;
      _permissionError = 'Location permissions are permanently denied. Please enable them in App Settings.';
      notifyListeners();
      return false;
    }

    // Mark setup completed so future launches never prompt again
    await AppConfig.setLocationSetupCompleted(true);

    // Start native Android Foreground Service
    await _ensureNativeServiceRunning();
    _status = SharingStatus.active;
    _permissionError = null;
    notifyListeners();

    // Fetch initial coordinates
    await fetchLatestLocationFromNative();
    return true;
  }

  /// Starts or confirms the native Android Foreground Service is running
  Future<void> _ensureNativeServiceRunning() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool isRunning = await _channel.invokeMethod('isLocationServiceRunning') ?? false;
        if (!isRunning) {
          debugPrint('[LocationService] Starting native Android LocationForegroundService with interval ${AppConfig.updateIntervalSeconds}s');
          await _channel.invokeMethod('startLocationService', {
            'backend_url': AppConfig.locationApiUrl.replaceAll('/api/location', ''),
            'interval_seconds': AppConfig.updateIntervalSeconds,
          });
        } else {
          debugPrint('[LocationService] Native LocationForegroundService is already running.');
        }
      } catch (e) {
        debugPrint('[LocationService] Error starting native location service: $e');
      }
    }
  }

  /// Restarts the native Android service (e.g. after changing update interval or URL)
  Future<void> restartService() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startLocationService', {
          'backend_url': AppConfig.locationApiUrl.replaceAll('/api/location', ''),
          'interval_seconds': AppConfig.updateIntervalSeconds,
        });
      } catch (e) {
        debugPrint('[LocationService] restartService error: $e');
      }
    }
  }

  /// Device settings shortcuts
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }
}

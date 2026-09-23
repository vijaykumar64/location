import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../models/location_data.dart';
import 'api_service.dart';

enum SharingStatus {
  idle,
  active,
  gpsDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal() {
    _initServiceListener();
  }

  SharingStatus _status = SharingStatus.idle;
  SharingStatus get status => _status;
  bool get isSharing => _status == SharingStatus.active;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  LocationDataModel? _lastUploadedLocation;
  LocationDataModel? get lastUploadedLocation => _lastUploadedLocation;

  String? _uploadError;
  String? get uploadError => _uploadError;

  String? _permissionError;
  String? get permissionError => _permissionError;

  bool _isGpsEnabled = true;
  bool get isGpsEnabled => _isGpsEnabled;

  LocationPermission _permission = LocationPermission.denied;
  LocationPermission get permission => _permission;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _periodicTimer;

  void _initServiceListener() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        _isGpsEnabled = (status == ServiceStatus.enabled);
        if (!_isGpsEnabled && _status == SharingStatus.active) {
          _status = SharingStatus.gpsDisabled;
          _uploadError = 'Location services (GPS) disabled on device.';
          notifyListeners();
        } else if (_isGpsEnabled && _status == SharingStatus.gpsDisabled) {
          startTracking();
        }
      });
    }
  }

  /// 1. Check whether location services are enabled
  Future<bool> checkLocationServiceEnabled() async {
    _isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isGpsEnabled) {
      _status = SharingStatus.gpsDisabled;
      _permissionError = 'Location services are disabled on your device. Please turn on GPS.';
      notifyListeners();
      return false;
    }
    return true;
  }

  /// 2. Request location permission with proper status handling
  Future<LocationPermission> requestPermission() async {
    _permission = await Geolocator.checkPermission();

    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }

    if (_permission == LocationPermission.denied) {
      _status = SharingStatus.permissionDenied;
      _permissionError = 'Location permission is required to share your coordinates with Y.';
      notifyListeners();
      return _permission;
    }

    if (_permission == LocationPermission.deniedForever) {
      _status = SharingStatus.permissionPermanentlyDenied;
      _permissionError = 'Location permissions are permanently denied. Please enable them in App Settings.';
      notifyListeners();
      return _permission;
    }

    _permissionError = null;
    notifyListeners();
    return _permission;
  }

  /// 3. Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _currentPosition = position;
      notifyListeners();
      return position;
    } catch (e) {
      debugPrint('[LocationService] getCurrentLocation error: $e');
      return null;
    }
  }

  /// 4. Start continuous tracking and real-time location sharing without break
  Future<bool> startTracking() async {
    // Step 1: Check location services enabled
    final serviceEnabled = await checkLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Step 2: Request permission
    final perm = await requestPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
      return false;
    }

    _status = SharingStatus.active;
    _uploadError = null;
    _permissionError = null;
    notifyListeners();

    // Trigger immediate location capture and upload
    await _captureAndUploadLocation();

    final intervalSec = AppConfig.updateIntervalSeconds;

    // Android foreground service settings for uninterrupted real-time streaming
    late LocationSettings locationSettings;
    if (!kIsWeb && Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // 0 meters so continuous updates are sent even when stationary
        intervalDuration: Duration(seconds: intervalSec),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: "Continuous Location Sharing Active",
          notificationText: "Real-time updates sending every $intervalSec sec without break.",
          enableWakeLock: true, // Prevents CPU sleep
        ),
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 15),
      );
    }

    // Subscribe to continuous position stream with foreground notification
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        if (_status != SharingStatus.active) return;
        _currentPosition = position;
        await _uploadPosition(position);
      },
      onError: (error) {
        debugPrint('[LocationService] Stream error: $error');
      },
    );

    // Periodic backup timer to ensure continuous sending without break even if stream stalls
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(Duration(seconds: intervalSec), (_) async {
      if (_status == SharingStatus.active && !_isUploading) {
        await _captureAndUploadLocation();
      }
    });

    return true;
  }

  /// Helper: Capture GPS location and attempt upload
  Future<void> _captureAndUploadLocation() async {
    if (_isUploading) return;
    _isUploading = true;
    notifyListeners();

    try {
      final position = await getCurrentLocation();
      if (position != null) {
        await _uploadPosition(position);
      } else {
        _uploadError = 'Unable to acquire GPS signal.';
      }
    } catch (e) {
      _uploadError = e.toString();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Helper: Upload position to backend
  Future<void> _uploadPosition(Position position) async {
    try {
      final uploaded = await ApiService.uploadLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      _lastUploadedLocation = uploaded;
      _uploadError = null; // Cleared on successful upload
      notifyListeners();
    } on ApiException catch (e) {
      _uploadError = e.message;
      notifyListeners();
    } catch (e) {
      _uploadError = 'Upload failed: $e';
      notifyListeners();
    }
  }

  /// 5. Stop tracking and all backend updates
  Future<void> stopTracking() async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _periodicTimer?.cancel();
    _periodicTimer = null;

    _status = SharingStatus.idle;
    _uploadError = null;
    notifyListeners();
  }

  /// Restart tracking (used when interval is changed in settings while sharing is active)
  Future<void> restartTracking() async {
    if (isSharing) {
      await stopTracking();
      await startTracking();
    }
  }

  /// Device settings helpers
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  void dispose() {
    _serviceStatusSubscription?.cancel();
    stopTracking();
    super.dispose();
  }
}

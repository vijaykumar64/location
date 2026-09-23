import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../models/location_data.dart';
import 'background_service.dart';

enum SharingStatus {
  initializing,
  active,
  gpsDisabled,
  permissionRequired,
  permissionPermanentlyDenied,
}

class LocationService extends ChangeNotifier {
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

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  /// Initializes the service on app launch
  Future<void> initialize() async {
    // 1. Load cached coordinates from local storage for instant display
    final cached = await AppConfig.getLastLocation();
    if (cached != null) {
      _latitude = cached['latitude'];
      _longitude = cached['longitude'];
      _accuracy = cached['accuracy'];
      _lastUpdated = cached['timestamp'];
    }

    // 2. Register background isolate message receiver
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // 3. Listen to device GPS hardware switch (on/off)
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

    // 4. Check battery optimization state
    await checkBatteryOptimization();

    // 5. Check permissions and auto-start if already granted
    await checkAndAutoStart();
  }

  void _onReceiveTaskData(dynamic data) {
    if (data is Map) {
      debugPrint('[LocationService] Received data from background isolate: $data');
      if (data['success'] == true) {
        _latitude = (data['latitude'] as num?)?.toDouble() ?? _latitude;
        _longitude = (data['longitude'] as num?)?.toDouble() ?? _longitude;
        _accuracy = (data['accuracy'] as num?)?.toDouble() ?? _accuracy;
        if (data['timestamp'] != null) {
          _lastUpdated = DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now();
        }
        _uploadError = null;
        _status = SharingStatus.active;
      } else {
        _uploadError = data['error']?.toString();
      }
      notifyListeners();
    }
  }

  /// Checks battery optimization status on Android
  Future<void> checkBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      _isBatteryOptimizationRestricted = !isIgnoring;
      notifyListeners();
    }
  }

  /// Requests user to whitelist app from aggressive battery optimizations
  Future<void> requestIgnoreBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      await Future.delayed(const Duration(seconds: 1));
      await checkBatteryOptimization();
    }
  }

  /// Checks existing permissions and automatically starts/reconnects the foreground service
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
      // Permissions are already granted: DO NOT ask again!
      _permissionError = null;
      await _ensureForegroundServiceRunning();
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

  /// Performs first-time permission requests and automatically begins background sharing
  Future<bool> requestPermissionsAndStart() async {
    _isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isGpsEnabled) {
      _status = SharingStatus.gpsDisabled;
      notifyListeners();
      return false;
    }

    // 1. Request Notification permission on Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      final notifStatus = await FlutterForegroundTask.checkNotificationPermission();
      if (notifStatus != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }

    // 2. Request Location Permission
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

    // 3. Mark setup completed so subsequent launches never prompt again
    await AppConfig.setLocationSetupCompleted(true);

    // 4. Start foreground service
    await _ensureForegroundServiceRunning();
    _status = SharingStatus.active;
    _permissionError = null;
    notifyListeners();

    // 5. Fetch first immediate coordinates
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _latitude = pos.latitude;
      _longitude = pos.longitude;
      _accuracy = pos.accuracy;
      _lastUpdated = DateTime.now();
      await AppConfig.saveLastLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: _lastUpdated!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[LocationService] Initial position acquire error: $e');
    }

    return true;
  }

  /// Configures and starts the native Android Foreground Service
  Future<void> _ensureForegroundServiceRunning() async {
    final intervalMs = AppConfig.updateIntervalSeconds * 1000;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_sharing_channel',
        channelName: 'Location Sharing Active',
        channelDescription: 'Persistent background location sharing for Sender X',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        enableVibration: false,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervalMs),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      debugPrint('[LocationService] Starting native Android ForegroundService with interval ${AppConfig.updateIntervalSeconds}s');
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Location sharing is active',
        notificationText: 'Your location is being shared in the background.',
        callback: startCallback,
      );
    } else {
      debugPrint('[LocationService] Foreground service already running; restarting with latest config...');
      await FlutterForegroundTask.restartService();
    }
  }

  /// Restarts foreground service (e.g. after changing update interval)
  Future<void> restartService() async {
    if (_status == SharingStatus.active) {
      await _ensureForegroundServiceRunning();
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
    _serviceStatusSubscription?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }
}

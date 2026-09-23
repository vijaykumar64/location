import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/location_data.dart';

enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class SocketService extends ChangeNotifier {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  SocketConnectionStatus _status = SocketConnectionStatus.disconnected;
  SocketConnectionStatus get status => _status;
  bool get isConnected => _status == SocketConnectionStatus.connected;

  LocationDataModel? _latestLocation;
  LocationDataModel? get latestLocation => _latestLocation;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _status = SocketConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _socket?.dispose();

      _socket = io.io(
        AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(999)
            .setTimeout(10000)
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[SocketService] Connected to backend: ${_socket!.id}');
        _status = SocketConnectionStatus.connected;
        _errorMessage = null;
        notifyListeners();
      });

      _socket!.onDisconnect((_) {
        debugPrint('[SocketService] Disconnected from backend');
        _status = SocketConnectionStatus.disconnected;
        notifyListeners();
      });

      _socket!.onConnectError((err) {
        debugPrint('[SocketService] Connect error: $err');
        _status = SocketConnectionStatus.error;
        _errorMessage = 'Unable to connect to server.';
        notifyListeners();
      });

      _socket!.onError((err) {
        debugPrint('[SocketService] Socket error: $err');
        _status = SocketConnectionStatus.error;
        notifyListeners();
      });

      // Listen for real-time location update event from backend
      _socket!.on('locationUpdated', (data) {
        debugPrint('[SocketService] locationUpdated event received: $data');
        if (data != null && data is Map<String, dynamic>) {
          _latestLocation = LocationDataModel.fromJson(data);
          notifyListeners();
        } else if (data != null && data is Map) {
          _latestLocation = LocationDataModel.fromJson(Map<String, dynamic>.from(data));
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[SocketService] Init error: $e');
      _status = SocketConnectionStatus.error;
      _errorMessage = 'Failed to initialize socket: $e';
      notifyListeners();
    }
  }

  void updateLocationManually(LocationDataModel location) {
    _latestLocation = location;
    notifyListeners();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _status = SocketConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

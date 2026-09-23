import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/location_data.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/map_view.dart';
import '../widgets/coordinate_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/server_config_dialog.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final SocketService _socketService = SocketService();
  GoogleMapController? _mapController;

  LocationDataModel? _location;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _socketService.addListener(_onSocketUpdated);
    _socketService.connect();
    _fetchInitialLocation();
  }

  @override
  void dispose() {
    _socketService.removeListener(_onSocketUpdated);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loc = await ApiService.fetchLatestLocation();
      if (!mounted) return;
      setState(() {
        _location = loc;
        _isLoading = false;
        _isOffline = false;
        _errorMessage = null;
      });
      _socketService.updateLocationManually(loc);
      _animateToLocation(loc.latitude, loc.longitude);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.isNetworkError) {
          _isOffline = true;
          _errorMessage = 'Unable to connect to server.';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load location: $e';
      });
    }
  }

  void _onSocketUpdated() {
    if (!mounted) return;

    final newLoc = _socketService.latestLocation;
    final socketConnected = _socketService.isConnected;

    setState(() {
      if (_socketService.errorMessage != null && !socketConnected) {
        _isOffline = true;
      } else if (socketConnected) {
        _isOffline = false;
        _errorMessage = null;
      }

      if (newLoc != null) {
        _location = newLoc;
        _isOffline = false;
        _errorMessage = null;
      }
    });

    if (newLoc != null) {
      _animateToLocation(newLoc.latitude, newLoc.longitude);
    }
  }

  void _animateToLocation(double lat, double lng) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 16),
        ),
      );
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_location == null) return;
    final urlStr = 'https://www.google.com/maps?q=${_location!.latitude},${_location!.longitude}';
    final uri = Uri.parse(urlStr);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Maps: $e')),
        );
      }
    }
  }

  void _openConfigDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerConfigDialog(),
    );
    if (updated == true && mounted) {
      _socketService.connect();
      _fetchInitialLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _location != null;
    final latStr = hasLocation ? _location!.latitude.toStringAsFixed(6) : '—';
    final lngStr = hasLocation ? _location!.longitude.toStringAsFixed(6) : '—';
    final accStr = hasLocation ? '${_location!.accuracy.toStringAsFixed(1)} m' : '—';
    final lastUpdatedStr = hasLocation
        ? DateFormat('hh:mm a').format(_location!.timestamp.toLocal())
        : '—';

    final isLive = _socketService.isConnected && !_isOffline && hasLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Live Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location',
            onPressed: _fetchInitialLocation,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Configuration',
            onPressed: _openConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Map View Widget
              LiveMapView(
                location: _location,
                isLoading: _isLoading,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (hasLocation) {
                    _animateToLocation(_location!.latitude, _location!.longitude);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Offline Warning Banner
              if (_isOffline || _errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_off, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Unable to connect to server.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Last known location: $lastUpdatedStr',
                          style: const TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Coordinates Details Card Widget
              CoordinateCard(
                latitude: latStr,
                longitude: lngStr,
                accuracy: accStr,
                lastUpdated: lastUpdatedStr,
                isOffline: _isOffline,
              ),
              const SizedBox(height: 16),

              // Status Indicator Badge Widget
              ReceiverStatusBadge(
                isLive: isLive,
                isOffline: _isOffline,
              ),
              const SizedBox(height: 20),

              // OPEN IN GOOGLE MAPS Button
              FilledButton.icon(
                onPressed: hasLocation ? _openInGoogleMaps : null,
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  'OPEN IN GOOGLE MAPS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Server: ${AppConfig.baseUrl}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../services/location_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/coordinate_card.dart';
import '../widgets/server_config_dialog.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.addListener(_onServiceUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_locationService.isSharing) {
        _locationService.checkLocationServiceEnabled();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _handleStartSharing() async {
    // 1. Check if location services (GPS) are on
    final gpsOn = await _locationService.checkLocationServiceEnabled();
    if (!gpsOn) {
      if (!mounted) return;
      _showGpsDisabledDialog();
      return;
    }

    // 2. Explain why location is needed before asking
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      final proceed = await _showPermissionRationaleDialog();
      if (!proceed) return;
    }

    // 3. Start tracking
    final started = await _locationService.startTracking();
    if (!started && mounted) {
      if (_locationService.status == SharingStatus.permissionPermanentlyDenied) {
        _showPermanentlyDeniedDialog();
      } else if (_locationService.status == SharingStatus.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to start sharing.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleStopSharing() async {
    await _locationService.stopTracking();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sharing stopped.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  Future<bool> _showPermissionRationaleDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Access Required'),
            content: const Text(
              'This Sender app shares your real-time coordinates with Phone Y.\n\n'
              'GPS location access is strictly used to obtain your current position and '
              'transmit it to the designated receiver while sharing is active.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Location Disabled'),
        content: const Text(
          'GPS location services are turned off on this device. Please turn on device location to begin sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _locationService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Permanently Denied'),
        content: const Text(
          'Location permission has been permanently denied. Please grant location permissions in Android App Settings to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _locationService.openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  void _openConfigDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerConfigDialog(),
    );
    if (updated == true && mounted) {
      if (_locationService.isSharing) {
        await _locationService.restartTracking();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSharing = _locationService.isSharing;
    final position = _locationService.currentPosition;
    final uploaded = _locationService.lastUploadedLocation;
    final uploadError = _locationService.uploadError;
    final permissionError = _locationService.permissionError;

    // Use latest available coordinates (either uploaded or from GPS)
    final latStr = position != null
        ? position.latitude.toStringAsFixed(6)
        : (uploaded != null ? uploaded.latitude.toStringAsFixed(6) : '—');
    final lngStr = position != null
        ? position.longitude.toStringAsFixed(6)
        : (uploaded != null ? uploaded.longitude.toStringAsFixed(6) : '—');
    final accStr = position != null
        ? '${position.accuracy.toStringAsFixed(1)} m'
        : (uploaded != null ? '${uploaded.accuracy.toStringAsFixed(1)} m' : '—');

    // Last updated timestamp: only show if an upload actually occurred
    final lastUpdatedStr = uploaded != null
        ? DateFormat('hh:mm a').format(uploaded.timestamp.toLocal())
        : '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Location Sender',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configure Backend URL & Interval',
            onPressed: _openConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section Header
              const Text(
                'Location Sharing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // Active / Stopped Status Indicator Widget
              StatusBadge(
                isSharing: isSharing,
                isUploading: _locationService.isUploading,
              ),
              const SizedBox(height: 24),

              // Coordinates Details Card Widget
              CoordinateCard(
                latitude: latStr,
                longitude: lngStr,
                accuracy: accStr,
                lastUpdated: lastUpdatedStr,
              ),
              const SizedBox(height: 16),

              // Offline / Error Banner
              if (uploadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Internet unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              uploadError,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Permission Warning Banner
              if (permissionError != null && !isSharing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          permissionError,
                          style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // START SHARING Button
              FilledButton(
                onPressed: isSharing ? null : _handleStartSharing,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF0F766E),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'START SHARING',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // STOP SHARING Button
              OutlinedButton(
                onPressed: isSharing ? _handleStopSharing : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: const Color(0xFFDC2626),
                  side: BorderSide(
                    color: isSharing ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'STOP SHARING',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Continuous Streaming: every ${AppConfig.updateIntervalSeconds}s • Server: ${AppConfig.baseUrl}',
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _hasPromptedPermissionOnLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.addListener(_onServiceUpdate);

    // Initialize service and check if first-time permission prompt is needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _locationService.initialize();
      if (!mounted) return;

      if (_locationService.status == SharingStatus.permissionRequired &&
          !_hasPromptedPermissionOnLaunch) {
        _hasPromptedPermissionOnLaunch = true;
        _showInitialPermissionFlow();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _locationService.checkAndAutoStart();
      _locationService.checkBatteryOptimization();
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

  /// First installation onboarding flow: Explains purpose and requests permissions
  Future<void> _showInitialPermissionFlow() async {
    final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Background Location Access'),
            content: const Text(
              'This application continuously shares your location with Receiver Y in the background.\n\n'
              'Android location permission is required so the service can continue updating your '
              'coordinates even when the app is minimized or closed.\n\n'
              'A persistent Android notification will clearly show that background sharing is active.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;

    if (proceed && mounted) {
      await _locationService.requestPermissionsAndStart();
    }
  }

  void _openConfigDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerConfigDialog(),
    );
    if (updated == true && mounted) {
      await _locationService.restartService();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _locationService.status;
    final isSharing = _locationService.isSharing;
    final lat = _locationService.latitude;
    final lng = _locationService.longitude;
    final acc = _locationService.accuracy;
    final uploadError = _locationService.uploadError;
    final permissionError = _locationService.permissionError;
    final isBatteryRestricted = _locationService.isBatteryOptimizationRestricted;

    final lastGps = _locationService.lastGpsUpdated;
    final lastServer = _locationService.lastServerUpdated;
    final isNativeRunning = _locationService.isNativeServiceRunning || isSharing;

    final latStr = lat != null ? lat.toStringAsFixed(6) : '—';
    final lngStr = lng != null ? lng.toStringAsFixed(6) : '—';
    final accStr = acc != null ? '${acc.toStringAsFixed(1)} m' : '—';
    final lastGpsStr = lastGps != null
        ? DateFormat('hh:mm:ss a').format(lastGps.toLocal())
        : '—';
    final lastServerStr = lastServer != null
        ? DateFormat('hh:mm:ss a').format(lastServer.toLocal())
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

              // Active / Initializing Status Indicator
              StatusBadge(
                isSharing: isSharing,
                isUploading: false,
              ),
              const SizedBox(height: 20),

              // Background Sharing Status Callout Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSharing ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSharing ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSharing ? Icons.check_circle_outline : Icons.info_outline,
                      color: isSharing ? const Color(0xFF059669) : const Color(0xFF64748B),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSharing
                                ? 'Your location is being shared in the background.'
                                : 'Background location service is initializing...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSharing ? const Color(0xFF065F46) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSharing ? 'Background service: RUNNING' : 'Background service: STOPPED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isSharing ? const Color(0xFF047857) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Coordinates Details Card
              CoordinateCard(
                updateInterval: '10 seconds',
                latitude: latStr,
                longitude: lngStr,
                accuracy: accStr,
                lastGpsUpdate: lastGpsStr,
                lastServerUpdate: lastServerStr,
                backgroundServiceStatus: isNativeRunning ? 'RUNNING' : 'STOPPED',
              ),
              const SizedBox(height: 16),

              // Battery Optimization Warning Banner
              if (isBatteryRestricted) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.battery_alert, color: Color(0xFFD97706), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Battery Optimization Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Battery optimization may stop background location updates. Please allow unrestricted battery usage for reliable background location sharing.',
                        style: TextStyle(color: Color(0xFF78350F), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => _locationService.requestIgnoreBatteryOptimization(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF92400E),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Allow Unrestricted Battery'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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

              // Permission Warning Banner / Action
              if (status == SharingStatus.permissionRequired) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permissionError ?? 'Location access is required to share coordinates.',
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _locationService.requestPermissionsAndStart(),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                        child: const Text('Grant Location Permission'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Permanently Denied Banner
              if (status == SharingStatus.permissionPermanentlyDenied) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location permission is permanently denied.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please open Android App Settings and grant Location permissions to allow background sharing.',
                        style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _locationService.openAppSettings(),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                        child: const Text('Open App Settings'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // GPS Disabled Banner
              if (status == SharingStatus.gpsDisabled) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Location (GPS) is turned off.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _locationService.openLocationSettings(),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                        child: const Text('Turn On Device Location'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Update Interval: 10 seconds • Server: ${AppConfig.baseUrl}',
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

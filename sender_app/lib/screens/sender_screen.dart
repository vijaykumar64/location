import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../widgets/quest_status_card.dart';
import '../widgets/radar_scanner_widget.dart';
import '../widgets/server_config_dialog.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  bool _hasPromptedPermissionOnLaunch = false;
  int _currentTabIndex = 0;

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
          builder: (ctx) => Dialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF8B5CF6).withAlpha(100), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(120)),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Location Quest Link',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'This application continuously shares your location with your family in the background.\n\n'
                    'Location access is required so the service can continue updating your coordinates '
                    'even when the app is minimized or closed.\n\n'
                    'A persistent notification will remain visible while background sharing is active.',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Grant Access & Begin Quest',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildHomeTab(),
            _buildActivityTab(),
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: HOME (LOCATION QUEST RADAR & MAIN STATUS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    final status = _locationService.status;
    final isSharing = _locationService.isSharing;
    final isBatteryRestricted = _locationService.isBatteryOptimizationRestricted;
    final isGpsEnabled = _locationService.isGpsEnabled;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          _buildTopBar(),
          const SizedBox(height: 18),

          // Central Hero Radar Scanner
          Center(
            child: RadarScannerWidget(
              isActive: isSharing,
              size: 250,
            ),
          ),
          const SizedBox(height: 20),

          // Main Mission Status Section
          _buildMainMissionStatus(isSharing),
          const SizedBox(height: 18),

          // Game-Style Connection Level Indicator
          _buildConnectionLevelBar(isSharing),
          const SizedBox(height: 18),

          // 3 Sleek Status Cards: GPS, LINK, SYNC
          Row(
            children: [
              Expanded(
                child: QuestStatusCard(
                  icon: Icons.satellite_alt_rounded,
                  title: 'GPS',
                  statusText: isGpsEnabled ? 'Connected' : 'Offline',
                  isConnected: isGpsEnabled && isSharing,
                  accentColor: const Color(0xFF06B6D4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuestStatusCard(
                  icon: Icons.bolt_rounded,
                  title: 'LINK',
                  statusText: isSharing ? 'Active' : 'Paused',
                  isConnected: isSharing,
                  accentColor: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuestStatusCard(
                  icon: Icons.sync_rounded,
                  title: 'SYNC',
                  statusText: isSharing ? 'Automatic' : 'Standby',
                  isConnected: isSharing,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Battery Optimization Warning Banner (Styled in dark game aesthetic)
          if (isBatteryRestricted) ...[
            _buildBatteryWarningCard(),
            const SizedBox(height: 14),
          ],

          // Permission Required Alert Card
          if (status == SharingStatus.permissionRequired) ...[
            _buildPermissionAlertCard(
              title: 'Permission Required',
              message: 'Location access is required to share your mission coordinates.',
              buttonLabel: 'Grant Access',
              onPressed: () => _locationService.requestPermissionsAndStart(),
            ),
            const SizedBox(height: 14),
          ],

          // Permission Permanently Denied Alert Card
          if (status == SharingStatus.permissionPermanentlyDenied) ...[
            _buildPermissionAlertCard(
              title: 'Permission Disabled',
              message: 'Please enable Location permission in Android App Settings to share coordinates.',
              buttonLabel: 'Open App Settings',
              onPressed: () => _locationService.openAppSettings(),
            ),
            const SizedBox(height: 14),
          ],

          // GPS Disabled Alert Card
          if (status == SharingStatus.gpsDisabled) ...[
            _buildPermissionAlertCard(
              title: 'GPS Sensor Inactive',
              message: 'Please enable Device Location (GPS) to resume satellite tracking.',
              buttonLabel: 'Turn On Device Location',
              onPressed: () => _locationService.openLocationSettings(),
            ),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Top header with title and avatar
  Widget _buildTopBar() {
    final isSharing = _locationService.isSharing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(90)),
                  ),
                  child: const Text(
                    'LEVEL 5',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LOCATION QUEST',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isSharing ? 'Your connection is active' : 'Location link paused',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        // Avatar / Quick Settings
        GestureDetector(
          onTap: _openConfigDialog,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF131B2E),
              border: Border.all(
                color: isSharing
                    ? const Color(0xFF10B981).withAlpha(160)
                    : const Color(0xFF8B5CF6).withAlpha(100),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSharing
                      ? const Color(0xFF10B981).withAlpha(50)
                      : const Color(0xFF8B5CF6).withAlpha(40),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'X',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                if (isSharing)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Main Status Card under Radar
  Widget _buildMainMissionStatus(bool isSharing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSharing
              ? const Color(0xFF8B5CF6).withAlpha(80)
              : const Color(0xFF334155).withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSharing
                ? const Color(0xFF8B5CF6).withAlpha(25)
                : Colors.transparent,
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // MISSION ACTIVE Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSharing ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  boxShadow: isSharing
                      ? [
                          const BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isSharing ? 'MISSION ACTIVE' : 'MISSION PAUSED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: isSharing ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // LOCATION SHARING ACTIVE
          Text(
            isSharing ? 'LOCATION SHARING ACTIVE' : 'LOCATION LINK PAUSED',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Friendly Family Message
          Text(
            isSharing
                ? 'Your location is being shared\nwith your family.'
                : 'Location sharing is currently paused.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // Connection Level / Game Status Bar
  Widget _buildConnectionLevelBar(bool isSharing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'CONNECTION LEVEL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              final isFilled = isSharing;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  boxShadow: isFilled
                      ? [
                          const BoxShadow(
                            color: Color(0xFF38BDF8),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Battery optimization alert card
  Widget _buildBatteryWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706).withAlpha(100), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD97706).withAlpha(20), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Optimize Background Link',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFDE68A),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Allow unrestricted battery usage for reliable continuous location sharing.',
            style: TextStyle(color: Color(0xFFFCD34D), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _locationService.requestIgnoreBatteryOptimization(),
              child: const Text('Allow Unrestricted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Permission/GPS alert card
  Widget _buildPermissionAlertCard({
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1322),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(120), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFEF4444).withAlpha(25), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFCA5A5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Color(0xFFFECACA), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: ACTIVITY (GAME-STYLE MISSION FEED)
  // ─────────────────────────────────────────────────────────────
  Widget _buildActivityTab() {
    final isSharing = _locationService.isSharing;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'QUEST ACTIVITY',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Real-time link status & mission integrity',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),

          // Overview Streak Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF131B2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(80), width: 1.2),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withAlpha(30), blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'MISSION STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSharing
                            ? const Color(0xFF10B981).withAlpha(40)
                            : const Color(0xFF64748B).withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSharing ? 'ACTIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isSharing ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '100% Operational Link',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Continuous background updates enabled via Android Foreground Service.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Activity Timeline
          const Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          _buildActivityItem(
            icon: Icons.shield_rounded,
            title: 'Location Service Active',
            subtitle: 'Android native foreground service operating',
            isActive: isSharing,
          ),
          _buildActivityItem(
            icon: Icons.sync_rounded,
            title: 'Automatic Sync',
            subtitle: 'Transmitting regular updates to family receiver',
            isActive: isSharing,
          ),
          _buildActivityItem(
            icon: Icons.satellite_alt_rounded,
            title: 'Connection Active',
            subtitle: 'High precision satellite positioning connected',
            isActive: isSharing,
          ),
          const SizedBox(height: 16),

          // Mission Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Keep your phone\'s battery unrestricted to ensure 24/7 background guard reliability.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF10B981).withAlpha(30)
                  : const Color(0xFF334155).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: PROFILE (GAME-STYLE AVATAR & SETTINGS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    final isSharing = _locationService.isSharing;
    final isBatteryRestricted = _locationService.isBatteryOptimizationRestricted;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'PROFILE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 20),

          // Profile Hero Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(80), width: 1.2),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withAlpha(25), blurRadius: 20),
              ],
            ),
            child: Column(
              children: [
                // Glowing Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withAlpha(120),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Location Quest Guardian',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Family Link Node',
                  style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // Status Badge in profile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSharing
                        ? const Color(0xFF10B981).withAlpha(30)
                        : const Color(0xFF64748B).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSharing ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSharing ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSharing ? 'GUARDIAN LINK ONLINE' : 'LINK PAUSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isSharing ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Mission Settings Header
          const Text(
            'SETTINGS & PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Battery Optimization Status Tile
          _buildSettingsTile(
            icon: Icons.battery_charging_full_rounded,
            title: 'Battery Optimization',
            subtitle: isBatteryRestricted ? 'Restricted (Tap to optimize)' : 'Unrestricted (Optimal)',
            trailingText: isBatteryRestricted ? 'FIX' : 'OK',
            trailingColor: isBatteryRestricted ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            onTap: () => _locationService.requestIgnoreBatteryOptimization(),
          ),

          // Network Link Settings Tile
          _buildSettingsTile(
            icon: Icons.cell_tower_rounded,
            title: 'Network & Server Link',
            subtitle: 'Configure streaming endpoints & pulse',
            trailingText: 'CONFIG',
            trailingColor: const Color(0xFF38BDF8),
            onTap: _openConfigDialog,
          ),

          // App Settings Tile
          _buildSettingsTile(
            icon: Icons.app_settings_alt_rounded,
            title: 'Device Permissions',
            subtitle: 'Manage system location settings',
            trailingText: 'OPEN',
            trailingColor: const Color(0xFF8B5CF6),
            onTap: () => _locationService.openAppSettings(),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Location Quest v1.0.0 • Guardian Build',
              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(80)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
    required Color trailingColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withAlpha(180),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: trailingColor.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: trailingColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: trailingColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: trailingColor.withAlpha(80)),
          ),
          child: Text(
            trailingText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: trailingColor,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: const Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentTabIndex,
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFF8B5CF6).withAlpha(60),
        elevation: 0,
        height: 65,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF38BDF8)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.explore_rounded, color: Color(0xFF8B5CF6)),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF10B981)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

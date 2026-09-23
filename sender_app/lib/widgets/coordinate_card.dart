import 'package:flutter/material.dart';

class CoordinateCard extends StatelessWidget {
  final String updateInterval;
  final String latitude;
  final String longitude;
  final String accuracy;
  final String lastGpsUpdate;
  final String lastServerUpdate;
  final String backgroundServiceStatus;

  const CoordinateCard({
    super.key,
    this.updateInterval = '10 seconds',
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.lastGpsUpdate,
    required this.lastServerUpdate,
    required this.backgroundServiceStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricRow('Update Interval', updateInterval),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Latitude', latitude),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Longitude', longitude),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Accuracy', accuracy),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Last GPS Update', lastGpsUpdate),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Last Server Update', lastServerUpdate),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _buildStatusRow('Background Service', backgroundServiceStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String status) {
    final isRunning = status.toUpperCase().contains('RUNNING');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isRunning ? const Color(0xFF065F46) : const Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class CoordinateCard extends StatelessWidget {
  final String latitude;
  final String longitude;
  final String accuracy;
  final String lastUpdated;
  final bool isOffline;

  const CoordinateCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.lastUpdated,
    this.isOffline = false,
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
            _buildMetricRow('Latitude', latitude),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Longitude', longitude),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildMetricRow('Accuracy', accuracy),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildMetricRow(
              isOffline ? 'Last Known Location' : 'Last Updated',
              lastUpdated,
            ),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
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
}

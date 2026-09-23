import 'package:flutter/material.dart';

class ReceiverStatusBadge extends StatelessWidget {
  final bool isLive;
  final bool isOffline;

  const ReceiverStatusBadge({
    super.key,
    required this.isLive,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isLive
              ? 'Sender is sharing'
              : (isOffline
                  ? 'Server unreachable (Showing last known)'
                  : 'Waiting for sender'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isLive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

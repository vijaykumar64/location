import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final bool isSharing;
  final bool isUploading;

  const StatusBadge({
    super.key,
    required this.isSharing,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSharing ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isSharing ? 'ACTIVE' : 'STOPPED',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isSharing ? const Color(0xFF16A34A) : const Color(0xFF64748B),
          ),
        ),
        if (isUploading) ...[
          const SizedBox(width: 12),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

class QuestStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String statusText;
  final bool isConnected;
  final Color accentColor;

  const QuestStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.statusText,
    this.isConnected = true,
    this.accentColor = const Color(0xFF06B6D4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? accentColor.withAlpha(70)
              : const Color(0xFF334155).withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected ? accentColor.withAlpha(25) : Colors.transparent,
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with ambient glowing container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withAlpha(60),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isConnected ? accentColor : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),

          // Header Label
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),

          // Status with glowing dot
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  boxShadow: isConnected
                      ? [
                          const BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isConnected
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

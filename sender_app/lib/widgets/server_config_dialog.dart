import 'package:flutter/material.dart';
import '../config/app_config.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _intervalController;
  late int _selectedSeconds;

  final List<int> _presetIntervals = [3, 5, 10, 30, 60, 300];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.baseUrl);
    _selectedSeconds = AppConfig.updateIntervalSeconds;
    _intervalController = TextEditingController(text: _selectedSeconds.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  String _formatInterval(int sec) {
    if (sec == 10) return '10s (Optimal)';
    if (sec < 60) return '${sec}s';
    final mins = (sec / 60).round();
    return '$mins min${mins > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFF8B5CF6).withAlpha(80), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with glowing icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(100)),
                    ),
                    child: const Icon(Icons.settings_input_antenna_rounded,
                        color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Network Link Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'BACKEND SERVER URL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFF8B5CF6).withAlpha(60)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  ),
                  hintText: 'https://location-9ql3.onrender.com',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'UPDATE PULSE INTERVAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 10),

              // Quick preset chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetIntervals.map((sec) {
                  final isSelected = _selectedSeconds == sec;
                  return ChoiceChip(
                    label: Text(
                      _formatInterval(sec),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF8B5CF6),
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF334155),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSeconds = sec;
                          _intervalController.text = sec.toString();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final newUrl = _urlController.text.trim();
                      final newIntervalSec =
                          int.tryParse(_intervalController.text.trim()) ?? _selectedSeconds;

                      if (newUrl.isNotEmpty) {
                        await AppConfig.setBaseUrl(newUrl);
                      }
                      await AppConfig.setUpdateIntervalSeconds(newIntervalSec);

                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

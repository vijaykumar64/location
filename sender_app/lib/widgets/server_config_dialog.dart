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

  final List<int> _presetIntervals = [3, 5, 10, 30, 60, 300, 900];

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
    if (sec < 60) return '${sec}s (Continuous)';
    final mins = (sec / 60).round();
    return '$mins min${mins > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Streaming & Server Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Backend Server URL:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://10.0.2.2:5000',
                helperText: 'Emulator: 10.0.2.2:5000 | Device: LAN IP:5000',
              ),
            ),
            const SizedBox(height: 18),
            const Text('Continuous Sending Interval:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // Quick preset chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _presetIntervals.map((sec) {
                final isSelected = _selectedSeconds == sec;
                return ChoiceChip(
                  label: Text(_formatInterval(sec)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0F766E).withAlpha(40),
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
            const SizedBox(height: 12),

            const Text('Custom Interval (Seconds):', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '5',
                helperText: 'e.g., 3 or 5 for live continuous streaming',
                suffixText: 'sec',
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val.trim());
                if (parsed != null && parsed > 0) {
                  setState(() {
                    _selectedSeconds = parsed;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final newUrl = _urlController.text.trim();
            final newIntervalSec = int.tryParse(_intervalController.text.trim()) ?? _selectedSeconds;

            if (newUrl.isNotEmpty) {
              await AppConfig.setBaseUrl(newUrl);
            }
            await AppConfig.setUpdateIntervalSeconds(newIntervalSec);

            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

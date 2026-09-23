import 'package:flutter/material.dart';
import '../config/app_config.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server Configuration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Backend Server URL:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'https://location-9ql3.onrender.com',
              helperText: 'Production: https://location-9ql3.onrender.com',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final newUrl = _urlController.text.trim();
            if (newUrl.isNotEmpty) {
              await AppConfig.setBaseUrl(newUrl);
            }
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: const Text('Save & Reconnect'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _found = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_found) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final value = barcodes.first.rawValue;
              if (value != null) {
                setState(() => _found = true);
                Navigator.pop(context, value);
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton.tonal(
                onPressed: () async {
                  final controller = TextEditingController();
                  final code = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Manual entry'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: 'Enter barcode/QR'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('OK')),
                      ],
                    ),
                  );
                  if (code != null && code.isNotEmpty) {
                    if (mounted) Navigator.pop(context, code);
                  }
                },
                child: const Text('Manual entry'),
              ),
            ),
          )
        ],
      ),
    );
  }
}